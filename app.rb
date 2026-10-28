require "json"
require "sinatra/base"
require_relative "lib/bulgarian_registry"
require_relative "lib/czech_registry"
require_relative "lib/estonian_registry"
require_relative "lib/finnish_registry"
require_relative "lib/french_registry"
require_relative "lib/latvian_registry"
require_relative "lib/lithuanian_registry"
require_relative "lib/norwegian_registry"
require_relative "lib/polish_registry"
require_relative "lib/slovak_registry"

class CompanyApi < Sinatra::Base
  SWAGGER_DIST = File.expand_path("node_modules/swagger-ui-dist", __dir__)
  SWAGGER_FILES = %w[
    swagger-ui.css
    swagger-ui-bundle.js
    swagger-ui-standalone-preset.js
    favicon-16x16.png
    favicon-32x32.png
  ].freeze

  set :public_folder, File.expand_path("public", __dir__)
  set :show_exceptions, false
  set :raise_errors, false

  get "/" do
    content_type :html, charset: "utf-8"
    send_file File.expand_path("public/index.html", __dir__)
  end

  get "/docs/?" do
    content_type :html, charset: "utf-8"
    send_file File.expand_path("public/docs/index.html", __dir__)
  end

  get "/docs/assets/:name" do
    name = params[:name].to_s
    path = File.join(SWAGGER_DIST, name)
    halt 404 unless SWAGGER_FILES.include?(name) && File.file?(path)

    send_file path
  end

  get "/openapi.yaml" do
    content_type "application/yaml"
    send_file File.expand_path("openapi.yaml", __dir__)
  end

  get "/companies/:country_code/:registry_code" do
    content_type :json, charset: "utf-8"
    country = params[:country_code].to_s.upcase
    code = params[:registry_code].to_s

    company = case country
    when "BG"
      unless code.match?(/\A\d{9}\z/)
        halt 400, { "error" => "The Bulgarian registry code must be a 9-digit number" }.to_json
      end
      BulgarianRegistry.lookup(code)
    when "CZ"
      unless code.match?(/\A\d{8}\z/)
        halt 400, { "error" => "The Czech registry code must be an 8-digit number" }.to_json
      end
      CzechRegistry.lookup(code)
    when "EE"
      unless code.match?(/\A\d{8}\z/)
        halt 400, { "error" => "The registry code must be an 8-digit number" }.to_json
      end
      EstonianRegistry.lookup(code)
    when "FI"
      normalized = FinnishRegistry.normalize(code)
      unless normalized
        halt 400, { "error" => "The Finnish registry code must look like 1234567-8" }.to_json
      end
      FinnishRegistry.lookup(normalized)
    when "FR"
      unless code.match?(/\A\d{9}\z/)
        halt 400, { "error" => "The French registry code must be a 9-digit number" }.to_json
      end
      FrenchRegistry.lookup(code)
    when "LV"
      unless code.match?(/\A\d{11}\z/)
        halt 400, { "error" => "The Latvian registry code must be an 11-digit number" }.to_json
      end
      LatvianRegistry.lookup(code)
    when "LT"
      unless code.match?(/\A\d{9}\z/)
        halt 400, { "error" => "The Lithuanian registry code must be a 9-digit number" }.to_json
      end
      LithuanianRegistry.lookup(code)
    when "NO"
      unless code.match?(/\A\d{9}\z/)
        halt 400, { "error" => "The Norwegian registry code must be a 9-digit number" }.to_json
      end
      NorwegianRegistry.lookup(code)
    when "PL"
      unless code.match?(/\A\d{10}\z/)
        halt 400, { "error" => "The Polish registry code must be a 10-digit number" }.to_json
      end
      PolishRegistry.lookup(code)
    when "SK"
      unless code.match?(/\A\d{8}\z/)
        halt 400, { "error" => "The Slovak registry code must be an 8-digit number" }.to_json
      end
      SlovakRegistry.lookup(code)
    else
      halt 422, {
        "error" => "Only Bulgarian, Czech, Estonian, Finnish, French, Latvian, Lithuanian, Norwegian, Polish and Slovak companies are supported",
        "country_code" => country
      }.to_json
    end

    if company.nil?
      halt 404, {
        "error" => "Company not found",
        "country_code" => country,
        "registry_code" => code
      }.to_json
    end

    company.to_json
  rescue BulgarianRegistry::Error, CzechRegistry::Error, EstonianRegistry::Error, FinnishRegistry::Error, FrenchRegistry::Error, LatvianRegistry::Error, LithuanianRegistry::Error, NorwegianRegistry::Error, PolishRegistry::Error, SlovakRegistry::Error
    halt 502, { "error" => "The business register request failed" }.to_json
  end

  not_found do
    content_type :json, charset: "utf-8"
    existing = response.body.join
    existing.start_with?("{") ? existing : { "error" => "Address not found" }.to_json
  end

  error do
    content_type :json, charset: "utf-8"
    { "error" => "The request failed" }.to_json
  end
end
