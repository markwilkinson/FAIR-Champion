require 'net/http'
require 'uri'
require 'json'
require 'openapi_parser'

# Hardcoded from query (could be params or config; extend to parse DCAT JSON-LD for generality)
openapi_url = 'https://foops.linkeddata.es/v2/api-docs'
concrete_endpoint = 'https://foops.linkeddata.es/assess/test/VER1'

# Local converter base URL (adjust if service name or port differs)
converter_base = 'http://swagger-converter:8080/api'

def fetch_json(url)
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  raise "Failed to fetch #{url}: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

def convert_swagger_to_openapi(openapi_url)
  converter_url = "#{converter_base}/convert?url=#{URI.encode_www_form_component(openapi_url)}"
  fetch_json(converter_url)
end

def template_to_regex(template)
  # Convert OpenAPI path template to regex, capturing named groups
  regex_str = template.gsub(/\{([^}]+)\}/, '(?<\1>[^\/]+)')
  regex_str = "^#{regex_str}$"
  Regexp.new(regex_str)
end

def match_path_to_template(concrete_path, paths)
  paths.each do |template, path_item|
    regex = template_to_regex(template)
    match = regex.match(concrete_path)
    return { template: template, path_item: path_item, param_values: match.named_captures } if match
  end
  nil
end

def get_input_parameters(operation)
  params = []
  # Add parameters (path, query, header, cookie)
  (operation.parameters || []).each do |p|
    params << {
      name: p.name,
      in: p.in,
      required: p.required,
      type: p.schema&.type,
      description: p.description,
      schema_ref: p.schema&.ref
    }
  end
  # Add requestBody if present
  if operation.request_body
    content = operation.request_body.content['application/json'] # Assume JSON; adjust per spec
    if content
      params << {
        name: 'requestBody',
        in: 'body',
        required: operation.request_body.required,
        type: content.schema&.type,
        description: operation.request_body.description,
        schema_ref: content.schema&.ref
      }
    end
  end
  params
end

# # Fetch original spec
# raw_spec = fetch_json(openapi_url)

# # Detect and convert if Swagger 2.0
# if raw_spec['swagger'] == '2.0'
#   puts "Detected Swagger 2.0; converting to OpenAPI 3.0 using local converter..."
#   spec_hash = convert_swagger_to_openapi(openapi_url)
# elsif raw_spec['openapi']&.start_with?('3.')
#   spec_hash = raw_spec
# else
#   raise "Unsupported spec version"
# end

# # Parse with openapi_parser (expects OpenAPI 3.x)
# spec = OpenAPIParser.parse(spec_hash)

# # Parse concrete endpoint
# uri = URI(concrete_endpoint)
# concrete_host = uri.host
# concrete_path = uri.path

# # Check host match (OpenAPI 3 uses 'servers')
# server = spec.servers.first # Assume first; check all if multiple
# server_uri = URI(server.url)
# unless concrete_host == server_uri.host
#   raise "Endpoint host does not match spec server: #{server_uri.host}"
# end

# # Adjust concrete path (servers may include base path)
# base_path = server_uri.path == '/' ? '' : server_uri.path
# relative_path = concrete_path.sub(/^#{Regexp.escape(base_path)}/, '')

# # Find matching path template
# match = match_path_to_template(relative_path, spec.paths)
# raise "No matching path template found for #{relative_path}" unless match

# # Assume POST operation (adjust if needed)
# operation = match[:path_item].post
# raise "No POST operation found for #{match[:template]}" unless operation

# # Get and print input parameters
# params = get_input_parameters(operation)
# puts "Matched path template: #{match[:template]}"
# puts "Extracted path param values: #{match[:param_values]}"
# puts "Input parameters for POST operation:"
# params.each do |param|
#   puts "- Name: #{param[:name]}"
#   puts "  In: #{param[:in]}"
#   puts "  Required: #{param[:required]}"
#   puts "  Type: #{param[:type]}"
#   puts "  Description: #{param[:description]}"
#   puts "  Schema Ref: #{param[:schema_ref]}" if param[:schema_ref]
#   puts
# end
