require "json"
require "net/http"
require "uri"

module NorwegianRegistry
  class Error < StandardError; end

  API = "https://data.brreg.no/enhetsregisteret/api/enheter"

  ROLES = {
    "DAGL" => "Managing director",
    "LEDE" => "Chair of the supervisory board",
    "NESTL" => "Vice-chair of the supervisory board",
    "MEDL" => "Supervisory board member",
    "VARA" => "Deputy board member",
    "REVI" => "Auditor",
    "REGN" => "Accountant",
    "INNH" => "Owner",
    "BOBE" => "Trustee in bankruptcy"
  }.freeze

  module_function

  def lookup(registry_code)
    status, body = request("#{API}/#{registry_code}")
    return nil if status == 404
    raise Error, "Norra register vastas staatusega #{status}" unless status == 200

    entity = parse_json(body)
    return nil if entity["organisasjonsnummer"].to_s != registry_code

    status_code, status_name, active, deleted_on = status_for(entity)
    {
      "country_code" => "NO",
      "registry_code" => registry_code,
      "name" => presence(entity["navn"]),
      "email" => presence(entity["epostadresse"]),
      "phone" => phones(entity),
      "address" => format_address(entity["forretningsadresse"] || entity["postadresse"]),
      "registered_on" => iso_date(entity["registreringsdatoEnhetsregisteret"]),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => representatives(registry_code)
    }
  end

  def status_for(entity)
    deleted_on = iso_date(entity["slettedato"])
    return ["K", "Deleted", false, deleted_on] if deleted_on
    return ["N", "In bankruptcy", false, nil] if entity["konkurs"]
    if entity["underAvvikling"] || entity["underTvangsavviklingEllerTvangsopplosning"]
      return ["L", "In liquidation", false, nil]
    end

    ["R", "Entered in the register", true, nil]
  end

  def representatives(registry_code)
    status, body = request("#{API}/#{registry_code}/roller")
    return [] if status == 404
    raise Error, "Norra register vastas staatusega #{status}" unless status == 200

    groups = Array(parse_json(body)["rollegrupper"])
    groups.flat_map { |group| Array(group["roller"]) }.filter_map { |role| representative(role) }
  rescue Error
    []
  end

  def representative(role)
    return nil if role["avregistrert"]

    person = role["person"]
    unit = role["enhet"]
    name = person.is_a?(Hash) ? person_name(person) : unit_name(unit)
    return nil if name.nil?

    code = role.dig("type", "kode").to_s
    label = presence(role.dig("type", "beskrivelse"))
    {
      "name" => name,
      "personal_code" => nil,
      "role" => ROLES.fetch(code, label),
      "valid_from" => nil
    }
  end

  def person_name(person)
    name = person["navn"]
    return nil unless name.is_a?(Hash)

    text = [name["fornavn"], name["mellomnavn"], name["etternavn"]].map { |part| presence(part) }.compact.join(" ")
    text.empty? ? nil : text
  end

  def unit_name(unit)
    return nil unless unit.is_a?(Hash)

    text = Array(unit["navn"]).map { |part| presence(part) }.compact.join(" ")
    text.empty? ? nil : text
  end

  def phones(entity)
    numbers = [entity["telefon"], entity["mobil"]].map { |value| presence(value) }.compact.uniq
    return nil if numbers.empty?

    numbers.join(", ")
  end

  def format_address(address)
    return nil unless address.is_a?(Hash)

    street = Array(address["adresse"]).map { |part| presence(part) }.compact.join(", ")
    locality = [presence(address["postnummer"]), presence(address["poststed"])].compact.join(" ")
    line = [street, locality].reject(&:empty?).join(", ")
    line.empty? ? nil : line
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Norra register ei tagastanud JSON-i"
  end

  def iso_date(value)
    text = presence(value)
    return nil if text.nil?

    text[0, 10] if text.match?(/\A\d{4}-\d{2}-\d{2}/)
  end

  def presence(value)
    text = value.to_s.strip
    text.empty? ? nil : text
  end

  def request(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 20
    message = Net::HTTP::Get.new(uri)
    message["User-Agent"] = "company-api-sample"
    message["Accept"] = "application/json"
    response = http.request(message)
    [response.code.to_i, response.body.to_s]
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, IOError => e
    raise Error, e.message
  end
end
