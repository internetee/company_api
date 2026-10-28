require "json"
require "net/http"
require "uri"

module SlovakRegistry
  class Error < StandardError; end

  API = "https://sluzby.orsr.sk/api"
  DELETED_EVENTS = %w[Vymaz Zrusenie PremenyZanik].freeze

  module_function

  def lookup(registry_code)
    match = find(registry_code)
    return nil if match.nil?

    extract = extract_for(match["fileReference"])
    body = extract.dig("legalPerson", "corporateBody")
    return nil unless body.is_a?(Hash)

    status_code, status_name, active, deleted_on = status_for(body)
    {
      "country_code" => "SK",
      "registry_code" => registry_code,
      "name" => current_text(body["corporateBodyFullName"]),
      "email" => nil,
      "phone" => nil,
      "address" => address(extract.dig("legalPerson", "physicalAddress")),
      "registered_on" => iso_date(body["establishment"]),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => representatives(body)
    }
  end

  def find(registry_code)
    query = URI.encode_www_form(
      "Filter.CorporateBodyFullNameOrRegistrationNumber" => registry_code,
      "Filter.IncludeTerminated" => "true",
      "Take" => "20"
    )
    status, payload = request("#{API}/legal-person?#{query}")
    raise Error, "Slovakkia register vastas staatusega #{status}" unless status == 200

    Array(payload["data"]).find { |row|
      row.is_a?(Hash) &&
        row["registrationNumber"].to_s == registry_code &&
        row["fileReference"].is_a?(Hash)
    }
  end

  def extract_for(reference)
    query = URI.encode_www_form(
      "oddiel" => reference["section"],
      "vlozka" => reference["insertNumber"],
      "sud" => reference["court"]
    )
    status, payload = request("#{API}/legal-person/extract?#{query}")
    raise Error, "Slovakkia register vastas staatusega #{status}" unless status == 200

    payload
  end

  def status_for(body)
    termination = iso_date(body["termination"])
    events = Array(body["legalStatusEvents"]).select { |row| row.is_a?(Hash) && row["current"] }
    deleted = events.find { |row| DELETED_EVENTS.include?(row["type"]) }
    if termination || deleted
      return ["K", "Deleted", false, termination || iso_date(deleted["dateTime"])]
    end
    if open_proceeding?(events, "KonkurzZaciatok", "KonkurzKoniec") ||
        open_proceeding?(events, "VyrovnanieZaciatok", "VyrovnanieKoniec") ||
        open_proceeding?(events, "NutenaSpravaZaciatok", "NutenaSpravaKoniec")
      return ["N", "In bankruptcy", false, nil]
    end
    return ["L", "In liquidation", false, nil] if open_proceeding?(events, "LikvidaciaZaciatok", "LikvidaciaKoniec")
    return ["RS", "Under restructuring", true, nil] if open_proceeding?(events, "RestrukturalizaciaZaciatok", "RestrukturalizaciaKoniec")

    text = fold(status_labels(body).join(" "))
    return ["K", "Deleted", false, nil] if text.match?(/vymaz|zrusen|zanik/)
    return ["N", "In bankruptcy", false, nil] if text.match?(/konkurz|vyrovn|nuten/)
    return ["L", "In liquidation", false, nil] if text.include?("likvid")
    return ["RS", "Under restructuring", true, nil] if text.include?("restrukt")

    ["R", "Entered in the register", true, nil]
  end

  def open_proceeding?(events, started, ended)
    starts = events.select { |row| row["type"] == started }
    return false if starts.empty?

    endings = events.select { |row| row["type"] == ended }
    return true if endings.empty?

    latest_time(starts) > latest_time(endings)
  end

  def latest_time(events)
    events.filter_map { |row| row["dateTime"].to_s }.max.to_s
  end

  def status_labels(body)
    Array(body["legalStatus"]).filter_map { |row|
      next unless row.is_a?(Hash) && row["current"]

      item = row["item"]
      if item.is_a?(String)
        presence(item)
      elsif item.is_a?(Hash)
        presence(item.dig("codelistItem", "itemName")) || presence(item["value"])
      end
    }
  end

  def representatives(body)
    people = Array(body["statutoryBody"]).filter_map { |row| representative(row, row["function"]) }
    people.concat(Array(body["stakeholder"]).filter_map { |row| representative(row, stakeholder_role(row)) })
    people.uniq
  end

  def representative(row, label)
    return nil unless row.is_a?(Hash) && row["current"] && row["functionTerminationDate"].nil?

    role = english_role(label)
    name = person_name(row["personData"])
    return nil if role.nil? || name.nil?

    {
      "name" => name,
      "personal_code" => nil,
      "role" => role,
      "valid_from" => iso_date(row["functionCreationDate"]) || iso_date(row["effectiveFrom"])
    }
  end

  def stakeholder_role(row)
    presence(row["function"]) ||
      presence(row.dig("stakeholderType", "item", "codelistItem", "itemName"))
  end

  def english_role(label)
    text = fold(label)
    return nil if text.empty?
    return "Vice-chair of the management board" if text.include?("podpredseda predstavenstva")
    return "Chair of the management board" if text.include?("predseda predstavenstva")
    return "Management board member" if text.include?("clen predstavenstva")
    return "Vice-chair of the supervisory board" if text.include?("podpredseda dozorn")
    return "Chair of the supervisory board" if text.include?("predseda dozorn")
    return "Supervisory board member" if text.include?("clen dozorn")
    return "Managing director" if text.include?("konatel")
    return "Procurator" if text.include?("prokur")
    return "Liquidator" if text.include?("likvidat")
    return "Trustee in bankruptcy" if text.match?(/spravca|konkurz/)
    return "Shareholder" if text.include?("spolocnik")
    return "Stockholder" if text.include?("akcionar")

    nil
  end

  def person_name(person)
    return nil unless person.is_a?(Hash)

    physical = person.dig("physicalPerson", "personName")
    if physical.is_a?(Hash)
      given = Array(physical["givenName"]).filter_map { |part| presence(part) }
      families = Array(physical["familyName"]).select { |part| part.is_a?(Hash) }
      primary = families.select { |part| part["primary"] }
      family = (primary.empty? ? families : primary).filter_map { |part| presence(part["value"]) }
      joined = (given + family).join(" ")
      return presence(joined) unless joined.empty?

      return presence(physical["formattedName"])
    end

    corporate = person["corporateBody"]
    return nil unless corporate.is_a?(Hash)

    labeled_name(corporate["corporateBodyFullName"])
  end

  def address(entries)
    rows = Array(entries).select { |row| row.is_a?(Hash) }
    row = rows.find { |item| item["current"] } || rows.first
    return nil unless row.is_a?(Hash)

    street = [presence(row["streetName"]), presence(row["buildingNumber"])].compact.join(" ")
    street = presence(row["addressLine"]) if street.empty?
    city = [postal_code(row.dig("deliveryAddress", "postalCode")), municipality_name(row)].compact.join(" ")
    presence([presence(street), presence(city)].compact.join(", "))
  end

  def municipality_name(address)
    item = address.dig("municipality", "item")
    return presence(item) if item.is_a?(String)
    return nil unless item.is_a?(Hash)

    presence(item.dig("codelistItem", "itemName")) || presence(item["value"])
  end

  def postal_code(value)
    text = presence(value)
    return nil if text.nil?

    digits = text.gsub(/\s+/, "")
    return "#{digits[0, 3]} #{digits[3, 2]}" if digits.match?(/\A\d{5}\z/)

    text
  end

  def current_text(entries)
    labeled_name(entries)
  end

  def labeled_name(value)
    case value
    when String
      presence(value)
    when Array
      rows = value.select { |row| row.is_a?(Hash) || row.is_a?(String) }
      chosen = rows.find { |row| row.is_a?(Hash) && row["current"] } || rows.first
      case chosen
      when String then presence(chosen)
      when Hash then presence(chosen["value"])
      end
    end
  end

  def fold(value)
    presence(value).to_s.unicode_normalize(:nfd).gsub(/\p{M}/, "").downcase
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
    [response.code.to_i, parse_json(response.body.to_s)]
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, IOError => e
    raise Error, e.message
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Slovakkia register ei tagastanud JSON-i"
  end
end
