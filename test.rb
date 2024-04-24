require 'sinatra'

post "/test" do
  "post test\n" + request.env["REQUEST_METHOD"]
end

get "/test" do
  "get test" + request.accept.first.to_s 

end

post "/test2" do
  #"type " + request.accept.first.to_s 
  redirect "/test", 307
end

post "/test3" do
  #"type " + request.accept.first.to_s
  status, headers, body = call env.merge("PATH_INFO" => '/test', 'REQUEST_METHOD' => "GET", 'HTTP_ACCEPT' => request.accept.first.to_s)
  [status, headers, body.map(&:upcase)]
end
