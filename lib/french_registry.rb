require "json"
require "net/http"
require "uri"

module FrenchRegistry
  class Error < StandardError; end

  API = "https://recherche-entreprises.api.gouv.fr/search"

  ROLES = {
    "president" => "President",
    "president du conseil d'administration" => "Chair of the supervisory board",
    "president du conseil d'administration et directeur general" => "President",
    "directeur general" => "Managing director",
    "directeur general delegue" => "Managing director",
    "gerant" => "Manager",
    "co-gerant" => "Manager",
    "administrateur" => "Supervisory board member",
    "administrateurs representant les salaries" => "Supervisory board member",
    "commissaire aux comptes titulaire" => "Auditor",
    "commissaire aux comptes suppleant" => "Auditor",
    "liquidateur" => "Liquidator",
    "associe" => "Shareholder",
    "associe unique" => "Shareholder",
    "membre" => "Member",
    "autre" => "Other"
  }.freeze

  module_function

  def lookup(registry_code)
    query = URI.encode_www_form("q" => registry_code, "per_page" => 10)
    status, body = request("#{API}?#{query}")
    raise Error, "Prantsuse register vastas staatusega #{status}" unless status == 200

    entity = Array(parse_json(body)["results"]).find { |item| item["siren"].to_s == registry_code }
    return nil if entity.nil?

    status_code, status_name, active, deleted_on = status_for(entity)
    {
      "country_code" => "FR",
      "registry_code" => registry_code,
      "name" => presence(entity["nom_complet"]) || presence(entity["nom_raison_sociale"]),
      "email" => nil,
      "phone" => nil,
      "address" => address(entity["siege"]),
      "registered_on" => iso_date(entity["date_creation"]),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => representatives(entity)
    }
  end

  def status_for(entity)
    deleted_on = iso_date(entity["date_fermeture"])
    return ["K", "Deleted", false, deleted_on] if entity["etat_administratif"].to_s == "C" || deleted_on

    ["R", "Entered in the register", true, nil]
  end

  def representatives(entity)
    Array(entity["dirigeants"]).filter_map { |person| representative(person) }
  end

  def representative(person)
    return nil unless person.is_a?(Hash)

    name = person["type_dirigeant"].to_s == "personne morale" ? presence(person["denomination"]) : person_name(person)
    return nil if name.nil?

    {
      "name" => name,
      "personal_code" => nil,
      "role" => role_name(person["qualite"]),
      "valid_from" => nil
    }
  end

  def person_name(person)
    text = [presence(person["prenoms"]), presence(person["nom"])].compact.join(" ")
    text.empty? ? nil : text
  end

  def role_name(qualite)
    text = presence(qualite)
    return nil if text.nil?

    key = text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("\u2019\u2018`", "'").downcase
    ROLES.fetch(key, text)
  end

  def address(siege)
    return nil unless siege.is_a?(Hash)

    presence(siege["adresse"])
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Prantsuse register ei tagastanud JSON-i"
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
