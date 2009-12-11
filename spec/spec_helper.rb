$TESTING=true
$:.push File.join(File.dirname(__FILE__), '..', 'lib')

require 'opscode/rest'
Opscode::REST::Log.level = :error
