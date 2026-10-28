require "cgi"
require "json"
require "net/http"
require "uri"

module EstonianRegistry
  class Error < StandardError; end

  STATUSES = {
    "R" => "Entered in the register",
    "L" => "In liquidation",
    "N" => "In bankruptcy",
    "K" => "Deleted"
  }.freeze

  ROLES = {
    "Juhatuse liige" => "Management board member",
    "Juhatuse esimees" => "Chair of the management board",
    "Juhatuse aseesimees" => "Vice-chair of the management board",
    "Nõukogu liige" => "Supervisory board member",
    "Nõukogu esimees" => "Chair of the supervisory board",
    "Nõukogu aseesimees" => "Vice-chair of the supervisory board",
    "Osanik" => "Shareholder",
    "Aktsionär" => "Stockholder",
    "Asutuse esindusõiguslik isik" => "Person authorised to represent the agency",
    "Kõrgemalseisev asutus" => "Superior agency",
    "Likvideerija" => "Liquidator",
    "Pankrotihaldur" => "Trustee in bankruptcy",
    "Prokurist" => "Procurator",
    "Asutaja" => "Founder",
    "Revisjonikomisjoni liige" => "Member of the audit committee",
    "Audiitor" => "Auditor",
    "Omanik" => "Owner",
    "Kaasomanik" => "Co-owner",
    "Liige" => "Member",
    "Esindusõiguslik juht" => "Representative manager",
    "Administraator" => "Administrator",
    "Volitatud esindaja" => "Authorised representative",
    "President" => "President",
    "Juhataja" => "Manager",
    "Pärandvara hooldaja" => "Estate trustee",
    "Tegevdirektor" => "Managing director",
    "Likvideerija esindaja" => "Representative of the liquidator"
  }.freeze

  module_function

  def lookup(registry_code)
    payload = get_json("https://ariregister.rik.ee/est/api/autocomplete?q=#{registry_code}&deleted_companies=1")
    row = Array(payload["data"]).find { |item| item["reg_code"].to_s == registry_code }
    return nil if row.nil?

    email = nil
    phone = nil
    registered_on = nil
    deleted_on = nil
    representatives = []
    status_code = row["status"].to_s
    begin
      page = get_text("https://ariregister.rik.ee/est/company/#{registry_code}")
      email = extract_email(page)
      phone = extract_phone(page)
      registered_on = extract_date(page, "Registreeritud")
      deleted_on = extract_date(page, "Kustutatud") if status_code == "K"
      representatives = extract_representatives(page)
    rescue Error
      email = nil
      phone = nil
      registered_on = nil
      deleted_on = nil
      representatives = []
    end

    {
      "country_code" => "EE",
      "registry_code" => registry_code,
      "name" => row["name"],
      "email" => email,
      "phone" => phone,
      "address" => format_address(row["legal_address"], row["zip_code"]),
      "registered_on" => registered_on,
      "deleted_on" => deleted_on,
      "active" => status_code == "R",
      "status" => {
        "code" => status_code,
        "name" => STATUSES.fetch(status_code, status_code)
      },
      "representatives" => representatives
    }
  end

  def extract_email(html)
    section = html[/Elektronposti aadress.{0,800}/m]
    return nil if section.nil?

    encoded = section[/data-cfemail="([0-9a-fA-F]+)"/, 1]
    return decode_email(encoded) if encoded

    text = plain(section.sub(/\A.*?>/, ""))
    text[/\A[\w.+\-]+@[\w.\-]+\.[A-Za-z]{2,}/]
  end

  def extract_phone(html)
    numbers = ["Telefon", "Mobiiltelefon"].filter_map { |label| labeled_value(html, label) }.uniq
    return nil if numbers.empty?

    numbers.join(", ")
  end

  def extract_date(html, label)
    iso_date(labeled_value(html, label))
  end

  def labeled_value(html, label)
    match = html.match(/text-muted">#{Regexp.escape(label)}<\/div>\s*<div class="col font-weight-bold">\s*([^<]+)/)
    return nil unless match

    value = plain(match[1])
    return nil if value.empty? || value == "-" || value == "—"

    value
  end

  def extract_representatives(html)
    table = html[/<table\b[^>]*id\s*=\s*"representativesTable"[^>]*>.*?<\/table>/m]
    return [] unless table

    table.scan(/<tr\b([^>]*)>(.*?)<\/tr>/m).filter_map do |attrs, inner|
      next if inner.include?("<th")
      next if attrs.match?(/\b(?:d-none|historic|history)\b/)

      cells = inner.scan(/<td\b[^>]*>(.*?)<\/td>/m).map { |cell| plain(cell[0]) }
      next if cells.size < 3 || cells[0].empty?

      {
        "name" => cells[0],
        "personal_code" => cells[1].empty? ? nil : cells[1],
        "role" => ROLES.fetch(cells[2], cells[2]),
        "valid_from" => iso_date(cells[3])
      }
    end
  end

  def decode_email(hex)
    return nil if hex.nil? || hex.length < 4 || hex.length.odd?

    key = hex[0, 2].to_i(16)
    email = hex[2..].scan(/../).map { |byte| (byte.to_i(16) ^ key).chr(Encoding::UTF_8) }.join
    email.match?(/\A[\w.+\-]+@[\w.\-]+\.[A-Za-z]{2,}\z/) ? email : nil
  end

  def format_address(street, zip)
    street = street.to_s.strip
    zip = zip.to_s.strip
    return nil if street.empty? && zip.empty?
    return street if zip.empty? || street.include?(zip)
    return zip if street.empty?

    "#{street}, #{zip}"
  end

  def plain(fragment)
    CGI.unescapeHTML(fragment.to_s.gsub(/<[^>]+>/, " ")).gsub(/\s+/, " ").strip
  end

  def iso_date(value)
    text = value.to_s
    return nil if text.empty?

    match = text.match(/(\d{2})\.(\d{2})\.(\d{4})/)
    return text unless match

    "#{match[3]}-#{match[2]}-#{match[1]}"
  end

  def get_json(url)
    status, body = request(url, "application/json")
    raise Error, "Äriregister vastas staatusega #{status}" unless status == 200

    JSON.parse(body)
  rescue JSON::ParserError
    raise Error, "Äriregister ei tagastanud JSON-i"
  end

  def get_text(url)
    status, body = request(url, "text/html")
    raise Error, "Ettevõtte kaart vastas staatusega #{status}" unless status == 200

    body
  end

  def request(url, accept)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 20
    message = Net::HTTP::Get.new(uri)
    message["User-Agent"] = "company-api-sample"
    message["Accept"] = accept
    response = http.request(message)
    [response.code.to_i, response.body.to_s]
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, IOError => e
    raise Error, e.message
  end
end
