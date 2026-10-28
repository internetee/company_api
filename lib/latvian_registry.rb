require "json"
require "net/http"
require "uri"

module LatvianRegistry
  class Error < StandardError; end

  REGISTER_RESOURCE = "25e80bf3-f107-4ab4-89ef-251b5b9374e9"
  OFFICER_RESOURCE = "e665114a-73c2-4375-9470-55874b4cfa6b"
  API = "https://data.gov.lv/dati/api/3/action/datastore_search"

  ROLES = {
    "BOARD_MEMBER" => "Management board member",
    "CHAIR_OF_BOARD" => "Chair of the management board",
    "CHAIR_OF_SUPERVISORY_BOARD" => "Chair of the supervisory board",
    "LIQUIDATOR" => "Liquidator",
    "OWNER" => "Owner",
    "CO_OWNER" => "Co-owner",
    "MEMBER" => "Member",
    "REPRESENTATIVE_MANAGER" => "Representative manager",
    "ADMINISTRATOR" => "Administrator",
    "AUTHORISED_REPRESENTATIVE" => "Authorised representative",
    "PRESIDENT" => "President",
    "MANAGER" => "Manager",
    "ESTATE_TRUSTEE" => "Estate trustee",
    "MANAGING_DIRECTOR" => "Managing director",
    "REPRESENTATIVE_OF_THE_LIQUIDATOR" => "Representative of the liquidator"
  }.freeze

  module_function

  def lookup(registry_code)
    row = find_company(registry_code)
    return nil if row.nil?

    status_code, status_name, active, deleted_on = status_for(row)
    {
      "country_code" => "LV",
      "registry_code" => registry_code,
      "name" => presence(row["name"]),
      "email" => nil,
      "phone" => nil,
      "address" => format_address(row),
      "registered_on" => iso_date(row["registered"]),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => representatives(registry_code)
    }
  end

  def find_company(registry_code)
    payload = search(REGISTER_RESOURCE, { "regcode" => registry_code.to_i }, 1)
    Array(payload.dig("result", "records")).find { |item| item["regcode"].to_s == registry_code }
  end

  def representatives(registry_code)
    rows = []
    offset = 0
    loop do
      payload = search(OFFICER_RESOURCE, { "at_legal_entity_registration_number" => registry_code.to_i }, 100, offset)
      batch = Array(payload.dig("result", "records"))
      rows.concat(batch)
      break if batch.size < 100 || rows.size >= 500

      offset += 100
    end
    rows.map { |row| representative(row) }
  rescue Error
    []
  end

  def representative(row)
    masked = presence(row["latvian_identity_number_masked"])
    legal_entity = presence(row["legal_entity_registration_number"])
    position = row["position"].to_s
    {
      "name" => presence(row["name"]),
      "personal_code" => masked || legal_entity,
      "role" => ROLES.fetch(position, presence(position)),
      "valid_from" => iso_date(row["registered_on"])
    }
  end

  def status_for(row)
    deleted_on = iso_date(row["terminated"])
    return ["R", "Entered in the register", true, nil] if deleted_on.nil?
    return ["REORG", "Reorganised", false, deleted_on] if row["closed"].to_s.strip == "R"

    ["K", "Deleted", false, deleted_on]
  end

  def format_address(row)
    street = row["address"].to_s.strip
    index = row["index"].to_i
    postal = format("LV-%04d", index) if index.positive?
    return nil if street.empty? && postal.nil?
    return street if postal.nil?
    return postal if street.empty?

    "#{street}, #{postal}"
  end

  def search(resource_id, filters, limit, offset = 0)
    query = URI.encode_www_form(
      "resource_id" => resource_id,
      "filters" => JSON.generate(filters),
      "limit" => limit,
      "offset" => offset
    )
    get_json("#{API}?#{query}")
  end

  def iso_date(value)
    match = value.to_s.match(/\A(\d{4}-\d{2}-\d{2})/)
    match && match[1]
  end

  def presence(value)
    text = value.to_s.strip
    return nil if text.empty? || text == "0"

    text
  end

  def get_json(url)
    status, body = request(url)
    raise Error, "Läti register vastas staatusega #{status}" unless status == 200

    payload = JSON.parse(body)
    raise Error, "Läti register ei tagastanud andmeid" unless payload["success"]

    payload
  rescue JSON::ParserError
    raise Error, "Läti register ei tagastanud JSON-i"
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
