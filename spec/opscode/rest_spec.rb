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

require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Opscode::REST do
  before(:each) do
    @rest = Opscode::REST.new
  end
  
  describe "initialize" do
    it "should set the cookies to an empty hash" do
      @rest.cookies.should == {}
    end
  end
  
  describe "request" do
    before(:each) do
      @options = {}
      @response = mock("RestClient::Response", :cookies => {}, :headers => {}, :null_object => true)
      @req = mock("RestClient::Request", :execute_inner => @response, :null_object => true)
      RestClient::Request.stub!(:new).and_return(@req)
    end
    
    it "should set the accept header to application/json if it is not set" do
      @rest.request(:get, 'http://example.com', @options)
      @options[:headers][:accept].should == "application/json"
    end
    
    it "should set the accept header to */* if it is not set explicitly for raw_responses" do
      @options[:raw_response] = true
      @rest.request(:get, 'http://example.com', @options)
      @options[:headers][:accept].should == "*/*"
    end
    
    it "should set the accept header to options[:headers][:accept] if it is provided" do
      @options[:headers] = { :accept => 'bang/bang' }
      @rest.request(:get, 'http://example.com', @options)
      @options[:headers][:accept].should == "bang/bang"
    end
    
    it "should set the cookies to those provided directly" do
      @options[:cookies] = { :what => 'are you doing!' }
      @rest.request(:get, 'http://example.com', @options)
      @options[:cookies].should == { :what => 'are you doing!' }
    end
    
    it "should set the cookies to those in the cookie jar if they are not provided" do
      @rest.cookies["example.com:80"] = { :frank => "hannon" }
      @rest.request(:get, 'http://example.com', @options)
      @options[:cookies].should == { :frank => "hannon" }
    end
    
    it "should set the cookies to an empty hash if there are no cookies at all" do
      @rest.request(:get, 'http://example.com', @options)
      @options[:cookies].should == {}
    end

    it "should build a RestClient::Request object" do
      RestClient::Request.should_receive(:new).and_return(@req)
      @rest.request(:get, 'http://example.com', @options)
    end
    
    it "should run the request" do
      @req.should_receive(:execute_inner).once
      @rest.request(:get, 'http://example.com', @options)
    end
  
    it "should set cookies if the response provided them" do
      @response.stub!(:cookies).and_return({ :edison => "liked electricity" })
      @response.stub!(:headers).and_return({ :set_cookie => true })
      @rest.request(:get, 'http://example.com', @options)
      @rest.cookies['example.com:80'][:edison].should == 'liked electricity'
    end
    
    it "should return a file descripter if a raw_response was requested" do
      tf = mock("Tempfile", :path => "/tmp/monkey")
      @response.stub!(:file).and_return(tf)
      @options[:raw_response] = true
      @rest.request(:get, 'http://example.com', @options).should == tf
    end
    
    it "should return a ruby object if the response was application/json" do
      @response.stub!(:headers).and_return({ :content_type => 'application/json' })
      @response.stub!(:to_s).and_return('{ "some":"value" }')
      results = @rest.request(:get, 'http://example.com', @options)
      results.should == { 'some' => 'value' }
    end
    
    it "should return the response body otherwise" do
      @response.stub!(:to_s).and_return('what you give')
      results = @rest.request(:get, 'http://example.com', @options)
      results.should == "what you give"
    end
  end
end