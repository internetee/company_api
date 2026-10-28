require "json"
require "net/http"
require "uri"

module CzechRegistry
  class Error < StandardError; end

  API = "https://ares.gov.cz/ekonomicke-subjekty-v-be/rest"
  ORGAN_KEYS = %w[statutarniOrgany ostatniOrgany akcionari spolecnici].freeze

  module_function

  def lookup(registry_code)
    status, body = request("#{API}/ekonomicke-subjekty/#{registry_code}")
    return nil if status == 404
    raise Error, "Tšehhi register vastas staatusega #{status}" unless status == 200

    subject = parse_json(body)
    return nil unless subject.is_a?(Hash) && subject["ico"].to_s == registry_code

    record = commercial_record(registry_code)
    status_code, status_name, active, deleted_on = status_for(subject, record)
    {
      "country_code" => "CZ",
      "registry_code" => registry_code,
      "name" => presence(subject["obchodniJmeno"]),
      "email" => nil,
      "phone" => nil,
      "address" => presence(subject.dig("sidlo", "textovaAdresa")),
      "registered_on" => iso_date(subject["datumVzniku"]),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => representatives(record)
    }
  end

  def commercial_record(registry_code)
    status, body = request("#{API}/ekonomicke-subjekty-vr/#{registry_code}")
    return nil if status == 404
    raise Error, "Tšehhi register vastas staatusega #{status}" unless status == 200

    rows = Array(parse_json(body)["zaznamy"]).select { |row| row.is_a?(Hash) }
    rows.find { |row| row["primarniZaznam"] } || rows.first
  end

  def status_for(subject, record)
    deleted_on = iso_date(subject["datumZaniku"])
    registers = subject["seznamRegistraci"].is_a?(Hash) ? subject["seznamRegistraci"] : {}
    register_status = record.is_a?(Hash) ? record["stavSubjektu"].to_s : ""
    if deleted_on || register_status == "ZANIKLY"
      return ["K", "Deleted", false, deleted_on]
    end
    if registers["stavZdrojeIr"] == "AKTIVNI" || registers["stavZdrojeCeu"] == "AKTIVNI"
      return ["N", "In bankruptcy", false, nil]
    end
    return ["L", "In liquidation", false, nil] if register_status.match?(/LIKVID/i)

    ["R", "Entered in the register", true, nil]
  end

  def representatives(record)
    return [] unless record.is_a?(Hash)

    ORGAN_KEYS.flat_map { |key|
      Array(record[key]).flat_map { |organ| members(organ) }
    }
  end

  def members(organ)
    return [] unless organ.is_a?(Hash) && organ["datumVymazu"].nil?

    Array(organ["clenoveOrganu"]).filter_map { |member| representative(member) }
  end

  def representative(member)
    return nil unless member.is_a?(Hash) && member["datumVymazu"].nil?

    role = english_role(member)
    name = person_name(member)
    return nil if role.nil? || name.nil?

    {
      "name" => name,
      "personal_code" => nil,
      "role" => role,
      "valid_from" => valid_from(member)
    }
  end

  def english_role(member)
    label = presence(member.dig("clenstvi", "funkce", "nazev")) || presence(member["nazevAngazma"])
    return nil if label.nil?

    text = label.downcase
    return "Vice-chair of the management board" if text.include?("místopředseda představenstva")
    return "Chair of the management board" if text.include?("předseda představenstva")
    return "Management board member" if text.include?("člen představenstva")
    return "Vice-chair of the supervisory board" if text.include?("místopředseda dozorčí rady")
    return "Chair of the supervisory board" if text.include?("předseda dozorčí rady")
    return "Supervisory board member" if text.include?("člen dozorčí rady")
    return "Managing director" if text.include?("jednatel")
    return "Procurator" if text.include?("prokur")
    return "Liquidator" if text.include?("likvidát")
    return "Trustee in bankruptcy" if text.include?("insolven")
    return "Shareholder" if text.include?("společník")
    return "Stockholder" if text.include?("akcionář")

    nil
  end

  def person_name(member)
    person = member["fyzickaOsoba"] || member["pravnickaOsoba"]
    return nil unless person.is_a?(Hash)

    name = [person["jmeno"], person["prijmeni"]].filter_map { |part| presence(part) }.join(" ")
    presence(name.empty? ? person["obchodniJmeno"] : name)
  end

  def valid_from(member)
    iso_date(member.dig("clenstvi", "funkce", "vznikFunkce")) ||
      iso_date(member.dig("clenstvi", "clenstvi", "vznikClenstvi")) ||
      iso_date(member["datumZapisu"])
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Tšehhi register ei tagastanud JSON-i"
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
