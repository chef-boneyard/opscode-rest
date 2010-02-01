#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

$: << File.join(File.dirname(__FILE__), "..", "..")

require 'rubygems'
require 'restclient'
require 'opscode/rest/config'
require 'opscode/rest/log'
require 'opscode/rest/resource'
require 'json'
require 'uri'
require 'mixlib/authentication/signedheaderauth'

# autoload workaround for nested classes
# module Mixlib
#   autoload :SignedHeaderAuth, 'mixlib/signedheaderauth'
# end

module Opscode
  class REST
    
    attr_accessor :cookies
    
    def initialize
      @cookies = Hash.new
    end
    
    # Authenticate this session via OpenID.  Takes the consumer URL (the place you want
    # to auth), an endpoint URL (the place your credentials live) and a password.
    #
    # === Parameters
    # consumer_url<String>:: The URL of the service you want to authenticate with.
    # endpoint_url<String>:: The URL of the endpoint where your credentials are.
    # pass<String>:: The passphrase to authenticate yourself with.
    #
    # === Returns
    # true:: Always returns true.
    def authenticate(consumer_url, endpoint_url, pass)
      Opscode::REST::Log.debug("Authenticating at #{consumer_url} for #{endpoint_url}")
      epoint_url = URI.parse(endpoint_url)
      response = request(
        :post,
        consumer_url,
        { 
          :payload => { 
            :openid_identifier => endpoint_url,
            :submit => "Verify"
          }
        }
      )
      scheme_class = epoint_url.scheme == 'http' ? URI::HTTP : URI::HTTPS
      verify_url = scheme_class.build({
        :host => epoint_url.host, 
        :port => epoint_url.port, 
        :userinfo => epoint_url.userinfo,
        :path => response['action']
      })
      response = request(
        :post,
        "#{verify_url}",
        { :payload => { :password => pass }, :rescue_redirects => false }
      )
      Opscode::REST::Log.debug("Authentication successful.")
      true
    end
    
    # Make a GET request.
    #
    #   rest.get('http://example.com', :payload => { :foo => 'bar' })
    #
    # Would generate GET http://example.com?foo=bar
    #
    # === Parameters
    # url<String>:: The URL to GET.
    # options<Hash>:: A hash of options for this request; see the documentation for 'request'
    #
    # === Returns
    # response<RestClient::Response>:: Returns a RestClient::Response
    def get(url, options={})
      request(:get, url, options)
    end
    
    # Make a PUT request.
    #
    # === Parameters
    # url<String>:: The URL to PUT.
    # options<Hash>:: A hash of options for this request; see the documentation for 'request'
    #
    # === Returns
    # response<RestClient::Response>:: Returns a RestClient::Response
    def put(url, options={})
      request(:put, url, options)
    end
    
    # Make a POST request.
    #
    # === Parameters
    # url<String>:: The URL to POST.
    # options<Hash>:: A hash of options for this request; see the documentation for 'request'
    #
    # === Returns
    # response<RestClient::Response>:: Returns a RestClient::Response
    def post(url, options={})
      request(:post, url, options)
    end
    
    # Make a HEAD request.
    #
    # === Parameters
    # url<String>:: The URL to call via HEAD.
    # options<Hash>:: A hash of options for this request; see the documentation for 'request'
    #
    # === Returns
    # response<RestClient::Response>:: Returns a RestClient::Response
    def head(url, options={})
      request(:head, url, options)
    end
    
    # Make an OPTIONS request.
    #
    # === Parameters
    # url<String>:: The URL to call via OPTIONS.
    # options<Hash>:: A hash of options for this request; see the documentation for 'request'
    #
    # === Returns
    # response<RestClient::Response>:: Returns a RestClient::Response
    def options(url, options={})
      request(:options, url, options)
    end
    
    # Make an HTTP request.  Requires the method (:get, :put, :post, :delete, :options, :head,)
    # and the URL to call.  Accepts a hash of Options to tweak the request.  Those parameters
    # are:
    #
    #  headers:: A hash of headers in RestClient symbol style.
    #  cookies:: A hash of cookies in RestClient symbol style.
    #  ssl_client_cert:: An SSL client certificate to use. Defaults to Config[:ssl_client_cert].
    #  ssl_client_key:: An SSL client key to use. Defaults to Config[:ssl_client_key].
    #  verify_ssl:: Whether or not to verify SSL; defaults to Config[:verify_ssl].
    #  user:: An HTTP Basic username; defaults to Config[:http_basic_username].
    #  pass:: The HTTP Basic auth password; defaults to Config[:http_basic_auth].
    #  timeout:: The HTTP request timeout; defaults to Config[:http_timeout].
    #  open_timeout:: The HTTP open timeout; defaults to Config[:http_open_timeout].
    #  raw_response:: Whether the response should be a RestClient::Response or RestClient::RawResponse.
    #  payload:: A hash of arguments, or a raw payload.
    #
    # === Parameters
    # method<Symbol>:: The method you want to use for this request. (:get, :put, :post, :delete, :options, :head)
    # url<String>:: The URL to retrieve.
    # options<Hash>:: A hash of options for this request; see the documentation for 'request'
    # limit<Integer>:: The number of redirects we follow before raising an ArgumentError.
    #
    # === Returns
    # response<RestClient::Response>:: Returns a RestClient::Response
    def request(method, url, options={}, limit=10)
      http_retry_delay = Opscode::REST::Config[:http_retry_delay] 
      http_retry_count = Opscode::REST::Config[:http_retry_count]
      
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0 
      
      url_object = URI.parse(url)
      cookie_key = "#{url_object.host}:#{url_object.port}"
      @cookies[cookie_key] = {} unless @cookies.has_key?(cookie_key)
          
      options[:headers] ||= Hash.new
        
      if options[:raw_response]
        options[:headers][:accept] = '*/*'
      elsif ! options[:headers].has_key?(:accept)
        options[:headers][:accept] = 'application/json'
      end
      
      options[:cookies] ||= @cookies[cookie_key]

      if options[:authenticate]
        ts = options[:timestamp] || Time.now.utc.iso8601
        body = options[:payload] || ""
        sign_obj = Mixlib::Authentication::SignedHeaderAuth.signing_object(:http_method=>method,:path=>url_object.path,:body=>body,:timestamp=>ts,:user_id=>options[:user_id])
        options[:headers].merge!(sign_obj.sign(options[:user_secret]))
      end
      
      req = RestClient::Request.new(
        :method => method,
        :url    => url,
        :ssl_client_cert => options[:ssl_client_cert] || Opscode::REST::Config[:ssl_client_cert],
        :ssl_client_key  => options[:ssl_client_key]  || Opscode::REST::Config[:ssl_client_key],
        :verify_ssl => options[:verify_ssl] || Opscode::REST::Config[:verify_ssl],
        :headers => options[:headers],
        :cookies => options[:cookies] || @cookies[cookie_key],
        :user => options[:user] || Opscode::REST::Config[:http_basic_username],
        :password => options[:password] || Opscode::REST::Config[:http_basic_password],
        :timeout => options[:timeout] || Opscode::REST::Config[:http_timeout],
        :open_timeout => options[:open_timeout] || Opscode::REST::Config[:http_open_timeout],
        :raw_response => options[:raw_response] || false,
        :payload => options[:payload] || nil
      )
      
      begin
        Opscode::REST::Log.debug("Sending HTTP #{method} request for #{url}")
        Opscode::REST::Log.debug("  Payload: #{req.payload.inspect}") if req.payload
        Opscode::REST::Log.debug("  User   : #{req.user}") if req.user
        Opscode::REST::Log.debug("  Pass   : #{req.password}") if req.password
        Opscode::REST::Log.debug("  Headers: #{req.headers.inspect}") if req.headers
        Opscode::REST::Log.debug("  Cookies: #{req.cookies.inspect}") if req.cookies
        Opscode::REST::Log.debug("  Raw    : #{req.raw_response}") 

        response = req.execute_inner
      rescue RestClient::Redirect => e
        @cookies[cookie_key] = e.response.cookies if e.response.headers[:set_cookie]
        redirect_url = URI.parse(e.url)
        redirect_url.scheme = url.scheme if redirect_url.scheme.nil?
        redirect_url.host = url.host if redirect_url.host.nil?
        redirect_url.port = url.port if redirect_url.port.nil?
        Opscode::REST::Log.debug("Redirecting HTTP #{method} request for #{url} to #{redirect_url.to_s}")
        return request(:get, redirect_url.to_s, { :raw_response => options[:raw_response] || false }, limit - 1)
      end
      
      @cookies[cookie_key] = response.cookies if response.headers[:set_cookie]
            
      if options[:raw_response]
        Opscode::REST::Log.debug("HTTP request successful - returning #{response.file.path}")
        response.file
      else
        if response.headers[:content_type] =~ /^application\/json/
          Opscode::REST::Log.debug("HTTP request successful - returning inflated JSON")
          JSON.parse(response.to_s)
        else
          Opscode::REST::Log.debug("HTTP request successful - returning response body")
          response.to_s
        end
      end
    end
  
  end
end
