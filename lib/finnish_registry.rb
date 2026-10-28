require "json"
require "net/http"
require "uri"

module FinnishRegistry
  class Error < StandardError; end

  STATUSES = {
    "0" => "Unregistered",
    "1" => "Entered in the register",
    "2" => "Removed from the register",
    "3" => "Unregistered start-up",
    "4" => "Ceased",
    "5" => "Business ID invalidated"
  }.freeze

  WEIGHTS = [7, 9, 10, 5, 8, 4, 2].freeze

  module_function

  def normalize(code)
    digits = code.to_s.strip.gsub(/[\s-]/, "")
    return nil unless digits.match?(/\A\d{8}\z/)

    base = digits[0, 7]
    check = digits[7].to_i
    sum = base.chars.each_with_index.sum { |char, index| char.to_i * WEIGHTS[index] }
    remainder = sum % 11
    return nil if remainder == 1

    expected = remainder.zero? ? 0 : 11 - remainder
    return nil unless expected == check

    "#{base}-#{check}"
  end

  def lookup(registry_code)
    payload = get_json("https://avoindata.prh.fi/opendata-ytj-api/v3/companies?businessId=#{registry_code}")
    company = Array(payload["companies"]).find { |item| item.dig("businessId", "value").to_s == registry_code }
    return nil if company.nil?

    status_code = status_code_for(company)
    {
      "country_code" => "FI",
      "registry_code" => registry_code,
      "name" => current_name(company["names"]),
      "email" => nil,
      "phone" => nil,
      "address" => current_address(company["addresses"]),
      "registered_on" => presence(company["registrationDate"]),
      "deleted_on" => presence(company["endDate"]),
      "active" => company["tradeRegisterStatus"].to_s == "1" && company["status"].to_s == "2",
      "status" => {
        "code" => status_code,
        "name" => STATUSES.fetch(status_code, status_code)
      },
      "representatives" => []
    }
  end

  def status_code_for(company)
    return "5" if company["status"].to_s == "5"

    company["tradeRegisterStatus"].to_s
  end

  def current_name(names)
    official = Array(names).select { |item| item["type"].to_s == "1" && item["endDate"].nil? }
    chosen = official.max_by { |item| [item["version"].to_i, item["registrationDate"].to_s] }
    chosen ||= Array(names).max_by { |item| item["registrationDate"].to_s }
    chosen && presence(chosen["name"])
  end

  def current_address(addresses)
    rows = Array(addresses)
    current = rows.select { |item| item["endDate"].nil? }
    current = rows if current.empty?
    row = current.find { |item| item["type"].to_i == 1 } || current.first
    return nil if row.nil?

    street = [row["street"], row["buildingNumber"]].map { |part| presence(part) }.compact.join(" ")
    office = Array(row["postOffices"]).find { |item| item["languageCode"].to_s == "1" } || Array(row["postOffices"]).first
    city = office && presence(office["city"])
    locality = [presence(row["postCode"]), city].compact.join(" ")
    line = [street, locality].reject(&:empty?).join(", ")
    line.empty? ? nil : line
  end

  def presence(value)
    text = value.to_s.strip
    text.empty? ? nil : text
  end

  def get_json(url)
    status, body = request(url)
    raise Error, "Soome register vastas staatusega #{status}" unless status == 200

    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Soome register ei tagastanud JSON-i"
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
