require "json"
require "net/http"
require "uri"

module LithuanianRegistry
  class Error < StandardError; end

  BASE = "https://get.data.gov.lt/datasets/gov/rc"

  STATUSES = {
    0 => ["R", "Entered in the register", true],
    1 => ["LT1", "Under reorganisation", true],
    2 => ["LT2", "Participating in reorganisation", true],
    3 => ["LT3", "Under conversion", true],
    4 => ["LT4", "Under restructuring", true],
    5 => ["LT5", "In bankruptcy proceedings", false],
    6 => ["LT6", "Bankrupt", false],
    7 => ["LT7", "In liquidation", false],
    8 => ["LT8", "Participating in a division", true],
    9 => ["LT9", "Liquidation being initiated", false],
    10 => ["LT10", "Removed from the register", false],
    11 => ["LT11", "Liquidated", false],
    12 => ["LT12", "Not reregistered", false],
    13 => ["LT13", "In bankruptcy proceedings", false],
    16 => ["LT16", "Forming a European company by merger", true],
    17 => ["LT17", "Forming a European company by holding", true],
    18 => ["LT18", "European company transferring its office", true],
    19 => ["LT19", "Forming a European cooperative by merger", true],
    20 => ["LT20", "European cooperative transferring its office", true],
    21 => ["LT21", "Cross-border merger", true],
    22 => ["LT22", "Participating in a cross-border merger", true],
    23 => ["LT23", "Cross-border merger", true],
    24 => ["LT24", "Participating in a cross-border merger", true],
    25 => ["LT25", "Transferring the registered office", true],
    26 => ["LT26", "In liquidation due to bankruptcy", false],
    27 => ["LT27", "Cross-border merger", true],
    28 => ["LT28", "Participating in a cross-border merger", true],
    29 => ["LT29", "Cross-border conversion", true],
    30 => ["LT30", "Cross-border division", true],
    31 => ["LT31", "Forming a controlling European company", true],
    32 => ["LT32", "Transferring the registered office to another country", true]
  }.freeze

  module_function

  def lookup(registry_code)
    row = find_company(registry_code)
    return nil if row.nil?

    status_code, status_name, active, deleted_on = status_for(row)
    company(registry_code, row["ja_pavadinimas"], address_for(row["_id"]), row["reg_data"], deleted_on, active, status_code, status_name)
  rescue Error
    company_from_fallback(registry_code)
  end

  def company(registry_code, name, address, registered_on, deleted_on, active, status_code, status_name)
    {
      "country_code" => "LT",
      "registry_code" => registry_code,
      "name" => presence(name),
      "email" => nil,
      "phone" => nil,
      "address" => presence(address),
      "registered_on" => presence(registered_on),
      "deleted_on" => deleted_on,
      "active" => active,
      "status" => { "code" => status_code, "name" => status_name },
      "representatives" => []
    }
  end

  def company_from_fallback(registry_code)
    status, body = request("https://jar.lapas.info/api.php?ids=#{registry_code}&show_l=true")
    payload = JSON.parse(body)
    return nil if status == 404 || [400, 404].include?(payload["status_code"].to_i)
    raise Error, "Leedu register vastas staatusega #{status}" unless status == 200 && payload["status_code"].to_i == 200

    row = Array(payload["data"]).find { |item| item["ja_kodas"].to_s == registry_code }
    return nil if row.nil?

    status_code, status_name, active, deleted_on = status_from_code(row["stat_kodas"], row["isreg_data"])
    company(registry_code, row["ja_pavadinimas"], row["adresas"], row["ja_reg_data"], deleted_on, active, status_code, status_name)
  rescue JSON::ParserError
    raise Error, "Leedu register ei tagastanud JSON-i"
  end

  def find_company(registry_code)
    status, body = request("#{BASE}/jar/iregistruoti/JuridinisAsmuo?ja_kodas=#{registry_code}&format(json)", read_timeout: 5)
    return nil if status == 500 && body.include?("UnexpectedToken")
    raise Error, "Leedu register vastas staatusega #{status}" unless status == 200

    payload = JSON.parse(body)
    Array(payload["_data"]).find { |item| item["ja_kodas"].to_s == registry_code }
  rescue JSON::ParserError
    raise Error, "Leedu register ei tagastanud JSON-i"
  end

  def status_for(row)
    status_from_code(status_code(row.dig("statusas", "_id")), row["isreg_data"])
  end

  def status_from_code(code, deleted_on)
    deleted_on = presence(deleted_on)
    mapped = code.nil? ? nil : STATUSES[code.to_i]
    if mapped
      status_code, status_name, active = mapped
    elsif deleted_on
      status_code = "K"
      status_name = "Deleted"
      active = false
    else
      status_code = "R"
      status_name = "Entered in the register"
      active = true
    end
    active = false if deleted_on
    [status_code, status_name, active, deleted_on]
  end

  def status_code(status_id)
    return nil if status_id.to_s.empty?

    payload = get_json("#{BASE}/jar/formos_statusai/Statusas?_id=%22#{status_id}%22&format(json)")
    record = Array(payload["_data"]).first
    record && record["kodas"].to_i
  rescue Error
    nil
  end

  def address_for(company_id)
    return nil if company_id.to_s.empty?

    offices = get_json("#{BASE}/jar/buveines/Buveine?juridinis_asmuo._id=%22#{company_id}%22&format(json)")
    office = Array(offices["_data"]).max_by { |item| item["adresas_nuo"].to_s }
    address_id = office && office.dig("adresas", "_id")
    return nil if address_id.to_s.empty?

    buildings = get_json("#{BASE}/ar/pastatas/Pastatas?aob_kodas._id=%22#{address_id}%22&format(json)")
    building = Array(buildings["_data"]).max_by { |item| item["aob_nuo"].to_s }
    return nil if building.nil?

    street = record("ar/gatve/Gatve", building.dig("gatve", "_id"))
    place = record("ar/gyvenamojivietove/GyvenamojiVietove", building.dig("gyvenamoji_vietove", "_id"))
    format_address(building, street, place)
  rescue Error
    nil
  end

  def format_address(building, street, place)
    number = [building["nr"], building["korpuso_nr"]].map { |part| presence(part) }.compact.join("-")
    street_line = if street
      [presence(street["pavadinimas"]), presence(street["tipo_santrumpa"]), number].compact.join(" ")
    else
      number
    end
    locality = place && presence(place["pavadinimas"])
    tail = [presence(building["pasto_kodas"]), locality].compact.join(" ")
    line = [street_line, tail].reject { |part| part.to_s.empty? }.join(", ")
    line.empty? ? nil : line
  end

  def record(path, id)
    return nil if id.to_s.empty?

    payload = get_json("#{BASE}/#{path}/#{id}?format(json)")
    payload["_data"].is_a?(Array) ? payload["_data"].first : payload
  end

  def presence(value)
    text = value.to_s.strip
    text.empty? ? nil : text
  end

  def get_json(url)
    status, body = request(url)
    raise Error, "Leedu register vastas staatusega #{status}" unless status == 200

    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Leedu register ei tagastanud JSON-i"
  end

  def request(url, read_timeout: 20)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = read_timeout
    message = Net::HTTP::Get.new(uri)
    message["User-Agent"] = "company-api-sample"
    message["Accept"] = "application/json"
    response = http.request(message)
    [response.code.to_i, response.body.to_s]
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, IOError => e
    raise Error, e.message
  end
end
