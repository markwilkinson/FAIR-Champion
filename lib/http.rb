module HTTPUtils
  require 'rest-client'

  def self.get(url:, headers: { accept: '*/*' }, user: '', pass: '') # username and password go into headers as user: xxx and password: yyy
    request = RestClient::Request.new({
                                        method: :get,
                                        url: url.to_s,
                                        user: user,
                                        password: pass,
                                        headers: headers
                                      })
    # warn "GET request headers:", request.headers
    request.execute
  rescue RestClient::ExceptionWithResponse => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue RestClient::Exception => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue Exception => e
    warn e
    false
    # now we are returning 'False', and we will check that with an \"if\" statement in our main code
    # you can capture the Exception and do something useful with it!\n",
  end

  def self.post(url:, headers: { accept: '*/*' }, payload:, user: '', pass: '', content_type: :json) # username and password go into headers as user: xxx and password: yyy
    RestClient::Request.execute({
                                  method: :post,
                                  url: url.to_s,
                                  user: user,
                                  password: pass,
                                  payload: payload,
                                  headers: headers
                                })
    # warn "POST request headers:", response.request.headers
  rescue RestClient::ExceptionWithResponse => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue RestClient::Exception => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue Exception => e
    warn e
    false
    # now we are returning 'False', and we will check that with an \"if\" statement in our main code
    # you can capture the Exception and do something useful with it!\n",
  end

  def self.put(url:, headers: { accept: '*/*' }, payload:, user: '', pass: '') # username and password go into headers as user: xxx and password: yyy
    RestClient::Request.execute({
                                  method: :put,
                                  url: url.to_s,
                                  user: user,
                                  password: pass,
                                  payload: payload,
                                  headers: headers
                                })
    # warn "PUT request headers:", response.request.headers
  rescue RestClient::ExceptionWithResponse => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue RestClient::Exception => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue Exception => e
    warn e
    false
    # now we are returning 'False', and we will check that with an \"if\" statement in our main code
    # you can capture the Exception and do something useful with it!\n",
  end

  def self.delete(url:, headers: { accept: '*/*' }, user: '', pass: '')
    RestClient::Request.execute({
                                  method: :delete,
                                  url: url.to_s,
                                  user: user,
                                  password: pass,
                                  headers: headers
                                })
    # warn "DELETE request headers:", response.request.headers
  rescue RestClient::ExceptionWithResponse => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue RestClient::Exception => e
    warn e.response
    false
  # now we are returning 'False', and we will check that with an \"if\" statement in our main code
  rescue Exception => e
    warn e
    false
    # now we are returning 'False', and we will check that with an \"if\" statement in our main code
    # you can capture the Exception and do something useful with it!\n",
  end

  def self.patchttl(body)
    # this will reorder the turtle so that all prefix lines are at the top
    # this is NOT the right thing to do (since prefixes are allowed to be redefined)
    # however, the turtle parser pukes on out-of-order @prefix lines
    # so... given that almost nobody ever redefines a prefix, this solves most problems...
    prefixes = []
    bodylines = []
    body.split("\n").each do |l|
      prefixes.concat([l]) if l =~ /^@prefix/i
      bodylines.concat([l]) unless l =~ /^@prefix/i
    end
    reintegrated = []
    reintegrated.concat([prefixes, bodylines])
    reintegrated.join("\n")
  end
end
