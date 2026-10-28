require "json"
require "net/http"
require "uri"

module PolishRegistry
  class Error < StandardError; end

  API = "https://api-krs.ms.gov.pl/api/krs"
  REGISTERS = %w[P S].freeze

  ROLES = {
    "PREZES ZARZĄDU" => "Chair of the management board",
    "WICEPREZES ZARZĄDU" => "Vice-chair of the management board",
    "CZŁONEK ZARZĄDU" => "Management board member",
    "PREZES RADY NADZORCZEJ" => "Chair of the supervisory board",
    "PRZEWODNICZĄCY RADY NADZORCZEJ" => "Chair of the supervisory board",
    "WICEPRZEWODNICZĄCY RADY NADZORCZEJ" => "Vice-chair of the supervisory board",
    "CZŁONEK RADY NADZORCZEJ" => "Supervisory board member",
    "PROKURENT" => "Procurator",
    "LIKWIDATOR" => "Liquidator",
    "SYNDYK" => "Trustee in bankruptcy"
  }.freeze

  module_function

  def lookup(registry_code)
    payload = find_extract(registry_code)
    return nil if payload.nil?

    odpis = payload["odpis"]
    return nil unless odpis.is_a?(Hash)

    dane = odpis["dane"]
    return nil unless dane.is_a?(Hash)

    header = odpis["naglowekA"] || odpis["naglowekP"] || {}
    name = text_field(dane.dig("dzial1", "danePodmiotu"), "nazwa")
    status_code, status_name, active, deleted_on = status_for(dane, header, name)
    {
      "country_code" => "PL",
      "registry_code" => presence(header["numerKRS"]) || registry_code,
      "name" => name,
      "email" => text_field(dane.dig("dzial1", "siedzibaIAdres"), "adresPocztyElektronicznej"),
      "phone" => nil,
      "address" => format_address(record(dane.dig("dzial1", "siedzibaIAdres", "adres"))),
      "registered_on" => registered_on(header),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => representatives(dane, header)
    }
  end

  def find_extract(registry_code)
    removed_from = nil
    REGISTERS.each do |register|
      status, body = request("#{API}/OdpisAktualny/#{registry_code}?rejestr=#{register}&format=json")
      return parse_json(body) if usable(status, body)
      if status == 204
        removed_from = register
        break
      end
      next if [400, 404].include?(status)

      raise Error, "Poola register vastas staatusega #{status}"
    end

    registers = removed_from ? [removed_from] : REGISTERS
    registers.each do |register|
      status, body = request("#{API}/OdpisPelny/#{registry_code}?rejestr=#{register}&format=json")
      return parse_json(body) if usable(status, body)
      next if [204, 400, 404].include?(status)

      raise Error, "Poola register vastas staatusega #{status}"
    end
    nil
  end

  def usable(status, body)
    status == 200 && !body.strip.empty?
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Poola register ei tagastanud JSON-i"
  end

  def status_for(dane, header, name)
    sections = dane["dzial6"].is_a?(Hash) ? dane["dzial6"] : {}
    upper = name.to_s.upcase
    if removed?(header)
      return ["K", "Deleted", false, removal_date(header)]
    end
    if bankruptcy?(sections) || upper.include?("W UPADŁOŚCI") || upper.include?("W UPADLOSCI")
      return ["N", "In bankruptcy", false, nil]
    end
    if liquidation?(sections) || upper.include?("W LIKWIDACJI")
      return ["L", "In liquidation", false, nil]
    end
    if restructuring?(sections) || upper.include?("W RESTRUKTURYZACJI")
      return ["RS", "Under restructuring", true, nil]
    end

    ["R", "Entered in the register", true, nil]
  end

  def removed?(header)
    Array(header["wpis"]).any? { |item| item.is_a?(Hash) && item["opis"].to_s.upcase.include?("WYKREŚL") }
  end

  def bankruptcy?(sections)
    present_section?(sections["postepowanieUpadlosciowe"])
  end

  def liquidation?(sections)
    present_section?(sections["likwidacja"]) || proceeding_liquidation?(sections["postepowanieRestrukturyzacyjneNaprawczePrzymusowaRestrukturyzacjaUporzadkowanaLikwidacja"])
  end

  def restructuring?(sections)
    present_section?(sections["postepowanieRestrukturyzacyjneNaprawczePrzymusowaRestrukturyzacjaUporzadkowanaLikwidacja"])
  end

  def proceeding_liquidation?(value)
    case value
    when Array
      value.any? { |item| proceeding_liquidation?(item) }
    when Hash
      return true if value["rodzajPostepowania"].to_s.upcase.include?("LIKWIDAC")

      value.any? { |key, item| !key.start_with?("nrWpisu") && proceeding_liquidation?(item) }
    else
      false
    end
  end

  def present_section?(value)
    case value
    when Array
      value.any? { |item| present_section?(item) }
    when Hash
      value.any? { |key, item| !key.start_with?("nrWpisu") && present_section?(item) }
    when String
      !value.strip.empty?
    when nil, false
      false
    else
      true
    end
  end

  def registered_on(header)
    iso_date(header["dataRejestracjiWKRS"]) || entry_date(header, "REJESTRACJA")
  end

  def removal_date(header)
    entry_date(header, "WYKREŚL")
  end

  def entry_date(header, marker)
    found = Array(header["wpis"]).find { |item| item.is_a?(Hash) && item["opis"].to_s.upcase.include?(marker) }
    iso_date(found && found["dataWpisu"])
  end

  def entry_dates(header)
    Array(header["wpis"]).each_with_object({}) do |item, dates|
      next unless item.is_a?(Hash)

      dates[item["numerWpisu"].to_i] = iso_date(item["dataWpisu"])
    end
  end

  def representatives(dane, header)
    dates = entry_dates(header)
    people = []
    list(dane.dig("dzial2", "reprezentacja")).each do |organ|
      fallback = organ_role(text_field(organ, "nazwaOrganu"), "Management board member")
      list(organ["sklad"]).each { |person| people << unwrap_person(person, fallback) }
    end
    list(dane.dig("dzial2", "organNadzoru")).each do |organ|
      fallback = organ_role(text_field(organ, "nazwa"), "Supervisory board member")
      list(organ["sklad"]).each { |person| people << unwrap_person(person, fallback) }
    end
    list(dane.dig("dzial2", "prokurenci")).each { |person| people << unwrap_person(person, "Procurator") }
    liquidation_people(dane).each { |person| people << unwrap_person(person, "Liquidator") }
    current_people(people, dates)
  end

  def liquidation_people(dane)
    sections = dane["dzial6"].is_a?(Hash) ? dane["dzial6"] : {}
    list(sections["likwidacja"]).flat_map { |node| list(node["likwidatorzy"]) }
  end

  def current_people(people, dates)
    rows = people.compact.select { |person| presence(person["name"]) }
    live = rows.reject { |person| person["struck"] }
    chosen = if live.empty?
      max_from = rows.map { |person| person["from"].to_i }.max
      rows.select { |person| person["from"].to_i == max_from }
    else
      live
    end
    chosen.map do |person|
      {
        "name" => person["name"],
        "personal_code" => person["personal_code"],
        "role" => person["role"],
        "valid_from" => dates[person["from"].to_i]
      }
    end
  end

  def unwrap_person(person, fallback)
    return nil unless person.is_a?(Hash)

    flat = {}
    struck = false
    from = 0
    person.each do |key, value|
      if versioned?(value)
        chosen = latest_version(value)
        next if chosen.nil?

        struck = true if presence(chosen["nrWpisuWykr"])
        from = [from, chosen["nrWpisuWprow"].to_i].max
        flat[key] = chosen.key?(key) ? chosen[key] : chosen.reject { |item_key, _| item_key.start_with?("nrWpisu") }
      else
        flat[key] = value
      end
    end
    {
      "name" => person_name(flat),
      "personal_code" => person_code(flat),
      "role" => person_role(flat, fallback),
      "struck" => struck,
      "from" => from
    }
  end

  def versioned?(value)
    value.is_a?(Array) && !value.empty? && value.all? { |item| item.is_a?(Hash) && (item.key?("nrWpisuWprow") || item.key?("nrWpisuWykr")) }
  end

  def person_name(person)
    surname = nested(person["nazwisko"], "nazwisko")
    given = nested(person["imiona"], "imiona")
    surname_parts = surname.is_a?(Hash) ? [surname["nazwiskoICzlon"], surname["nazwiskoIICzlon"]] : [surname]
    given_parts = given.is_a?(Hash) ? [given["imie"], given["imieDrugie"]] : [given]
    text = (given_parts + surname_parts).map { |part| presence(part) }.compact.join(" ")
    text.empty? ? nil : text
  end

  def person_code(person)
    identifier = nested(person["identyfikator"], "identyfikator")
    return nil unless identifier.is_a?(Hash)

    presence(identifier["pesel"])
  end

  def person_role(person, fallback)
    label = presence(person["funkcjaWOrganie"])
    return ROLES.fetch(label, label) if label

    fallback
  end

  def organ_role(name, fallback)
    text = name.to_s.upcase
    return "Supervisory board member" if text.include?("NADZOR") || text.include?("RADA")
    return "Management board member" if text.include?("ZARZĄD") || text.include?("ZARZAD")
    return "Liquidator" if text.include?("LIKWID")
    return "Procurator" if text.include?("PROKUR")

    fallback
  end

  def nested(value, key)
    return value[key] if value.is_a?(Hash) && value[key].is_a?(Hash)

    value
  end

  def format_address(adres)
    return nil unless adres.is_a?(Hash)

    number = [presence(adres["nrDomu"]), presence(adres["nrLokalu"])].compact.join("/")
    street = [presence(adres["ulica"]), number.empty? ? nil : number].compact.join(" ")
    locality = [presence(adres["kodPocztowy"]), presence(adres["miejscowosc"])].compact.join(" ")
    line = [street, locality].reject(&:empty?).join(", ")
    line.empty? ? nil : line
  end

  def text_field(node, key)
    return nil unless node.is_a?(Hash)

    value = node[key]
    if value.is_a?(Array)
      chosen = latest_version(value)
      return presence(chosen && chosen[key])
    end
    presence(value)
  end

  def record(node)
    return latest_version(node) if node.is_a?(Array)

    node if node.is_a?(Hash)
  end

  def latest_version(list)
    rows = list.select { |item| item.is_a?(Hash) }
    return nil if rows.empty?

    open = rows.reject { |item| presence(item["nrWpisuWykr"]) }
    pool = open.empty? ? rows : open
    pool.max_by { |item| item["nrWpisuWprow"].to_i }
  end

  def list(node)
    case node
    when Array then node
    when Hash then [node]
    else []
    end
  end

  def iso_date(value)
    text = presence(value)
    return nil if text.nil?
    return format("%s-%s-%s", text[6, 4], text[3, 2], text[0, 2]) if text.match?(/\A\d{2}\.\d{2}\.\d{4}/)

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
