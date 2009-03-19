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

require 'opscode/rest'

module Opscode
  class REST
    class Resource < RestClient::Resource
      
# A class that can be instantiated for access to a RESTful resource,
# including authentication.
#
# Example:
#
#   resource = Opscode::REST::Resource.new('http://some/resource')
#   jpg = resource.get(:accept => 'image/jpg')
#
# With HTTP basic authentication:
#
#   resource = Opscode::REST::Resource.new('http://protected/resource', :user => 'user', :password => 'password')
#   resource.delete
#
# With a timeout (seconds):
#
#   Opscode::REST::Resource.new('http://slow', :timeout => 10)
#
# With an open timeout (seconds):
#
#   Opscode::REST::Resource.new('http://behindfirewall', :open_timeout => 10)
#
# You can also use resources to share common headers. For headers keys,
# symbols are converted to strings. Example:
#
#   resource = Opscode::REST::Resource.new('http://some/resource', :headers => { :client_version => 1 })
#
# This header will be transported as X-Client-Version (notice the X prefix,
# capitalization and hyphens)
#
# Use the [] syntax to allocate subresources:
#
#   site = Opscode::REST::Resource.new('http://example.com', :user => 'adam', :password => 'mypasswd')
#   site['posts/1/comments'].post 'Good article.', :content_type => 'text/plain'
#
  		
  		attr_accessor :rest

  		def initialize(url, options={}, backwards_compatibility=nil)
  		  super(url, options, backwards_compatibility)  		  
  		  @rest = Opscode::REST.new
  		end

  		def get(additional_headers={})
  			@rest.request(:get, url, options.merge(
  				:headers => headers.merge(additional_headers)
  			))
  		end

  		def post(payload, additional_headers={})
  			@rest.request(:post, url, options.merge(
  				:payload => payload,
  				:headers => headers.merge(additional_headers)
  			))
  		end

  		def put(payload, additional_headers={})
  			@rest.request(:put, url, options.merge(
  				:payload => payload,
  				:headers => headers.merge(additional_headers)
  			))
  		end

  		def delete(additional_headers={})
  			@rest.request(:delete, url, options.merge(
  				:headers => headers.merge(additional_headers)
  			))
  		end

  		# Construct a subresource, preserving authentication.
  		#
  		# Example:
  		#
  		#   site = Opscode::REST::Resource.new('http://example.com', 'adam', 'mypasswd')
  		#   site['posts/1/comments'].post 'Good article.', :content_type => 'text/plain'
  		#
  		# This is especially useful if you wish to define your site in one place and
  		# call it in multiple locations:
  		#
  		#   def orders
  		#     Opscode::REST::Resource.new('http://example.com/orders', 'admin', 'mypasswd')
  		#   end
  		#
  		#   orders.get                     # GET http://example.com/orders
  		#   orders['1'].get                # GET http://example.com/orders/1
  		#   orders['1/items'].delete       # DELETE http://example.com/orders/1/items
  		#
  		# Nest resources as far as you want:
  		#
  		#   site = Opscode::REST::Resource.new('http://example.com')
  		#   posts = site['posts']
  		#   first_post = posts['1']
  		#   comments = first_post['comments']
  		#   comments.post 'Hello', :content_type => 'text/plain'
  		#
  		def [](suburl)
  		  me = super(suburl)
  		  me.rest = @rest
  			me
  		end
  		
  		def method_missing(method, *args)
  		  @rest.send(method, *args)
  		end
  	end
  end
end