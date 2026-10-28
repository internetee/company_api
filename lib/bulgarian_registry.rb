require "cgi"
require "json"
require "net/http"
require "openssl"
require "uri"

module BulgarianRegistry
  class Error < StandardError; end

  API = "https://portal.registryagency.bg/CR/api/Deeds"

  ROLES = {
    "CR_F_7_L" => "Manager",
    "CR_F_23_L" => "Owner",
    "CR_F_41_L" => "Procurator"
  }.freeze

  module_function

  def lookup(registry_code)
    status, body = request("#{API}/#{registry_code}")
    return nil if status == 404 || body.strip.empty?
    raise Error, "Bulgaaria register vastas staatusega #{status}" unless status == 200

    deed = parse_json(body)
    return nil unless deed.is_a?(Hash) && deed["uic"].to_s == registry_code

    status_code, status_name, active, deleted_on = status_for(deed)
    {
      "country_code" => "BG",
      "registry_code" => registry_code,
      "name" => presence(deed["fullName"]) || presence(deed["companyName"]),
      "email" => nil,
      "phone" => nil,
      "address" => address(deed),
      "registered_on" => registered_on(deed),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => representatives(deed)
    }
  end

  def status_for(deed)
    open_codes = Array(deed["sections"]).select { |section|
      Array(section["subDeeds"]).any? { |sub| !sub["subDeedIsClosed"] }
    }.map { |section| section["nameCode"].to_s }
    if open_codes.any? { |code| code.match?(/LIQUID/i) }
      return ["L", "In liquidation", false, nil]
    end
    if open_codes.any? { |code| code.match?(/INSOLVEN|BANKRUPT/i) }
      return ["N", "In bankruptcy", false, nil]
    end
    return ["K", "Deleted", false, nil] unless deed["deedStatus"].to_i == 2

    ["R", "Entered in the register", true, nil]
  end

  def representatives(deed)
    current_fields(deed).flat_map { |field| people(field) }
  end

  def people(field)
    role = ROLES[field["nameCode"]]
    return [] if role.nil? || field["fieldOperation"].to_i == 2

    html_records(field["htmlData"]).filter_map do |text|
      next if text.match?(/Заличен/i)

      name = display_name(text)
      next if name.nil?

      {
        "name" => name,
        "personal_code" => nil,
        "role" => role,
        "valid_from" => nil
      }
    end
  end

  def address(deed)
    field = current_fields(deed).find { |item| item["nameCode"] == "CR_F_5_L" }
    return nil if field.nil?

    plain(field["htmlData"])
  end

  def registered_on(deed)
    field = current_fields(deed).find { |item| item["nameCode"] == "CR_F_1_L" }
    return nil if field.nil?

    iso_date(field["recordMinActionDate"] || field["fieldEntryDate"])
  end

  def current_fields(deed)
    open_sections(deed).flat_map do |section|
      Array(section["subDeeds"]).reject { |sub| sub["subDeedIsClosed"] }.flat_map do |sub|
        Array(sub["groups"]).flat_map { |group| Array(group["fields"]) }
      end
    end
  end

  def open_sections(deed)
    Array(deed["sections"])
  end

  def html_records(html)
    html.to_s.split(/<hr\b[^>]*>/i).filter_map { |part| plain(part) }
  end

  def plain(html)
    text = html.to_s.gsub(/<br\s*\/?>/i, "\n").gsub(/<[^>]+>/, " ")
    text = CGI.unescapeHTML(text)
    text = text.gsub(/[ \t]+/, " ").gsub(/ *\n */, ", ").strip
    text.empty? ? nil : text
  end

  def display_name(text)
    name = text.split(/,\s*(?:Държава|Идентификация|Чуждестранно)\b/).first.to_s.strip
    name.empty? ? nil : name
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Bulgaaria register ei tagastanud JSON-i"
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

  def cert_store
    store = OpenSSL::X509::Store.new
    store.set_default_paths
    store.add_file(File.expand_path("sectigo_r46.pem", __dir__))
    store
  end

  def request(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.cert_store = cert_store
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
