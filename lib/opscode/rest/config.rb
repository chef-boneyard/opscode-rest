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

require 'rubygems'
require 'mixlib/config'

module Opscode
  class REST
    class Config
      extend Mixlib::Config
      
      log_level :warn
      log_location STDOUT
      http_retry_delay 5
      http_retry_count 5
      verify_ssl false
      ssl_client_cert nil
      ssl_client_key nil
      http_basic_username nil
      http_basic_password nil
      http_timeout nil
      http_open_timeout nil
      openid_consumer_url "http://localhost:4000"
      openid_endpoint_url "http://localhost:4001"
      
    end
  end
end
