require 'uri'
require 'ostruct'

# Check if command exists
def command?(name)
  `which #{name}`
  $?.success?
end

##
# Module to make tests integrate with WordPress and wp-cli
##
module WP
  # Use this test user for the tests
  # This is populated in bottom
  @@user = nil

  # Return siteurl
  # This works for subdirectory installations as well
  def self.siteurl(additional_path="/")
    if @@uri.port && ![443,80].include?(@@uri.port)
      return "#{@@uri.scheme}://#{@@uri.host}:#{@@uri.port}#{@@uri.path}#{additional_path}"
    else
      return "#{@@uri.scheme}://#{@@uri.host}#{@@uri.path}#{additional_path}"
    end
  end

  # sugar for @siteurl
  def self.url(path="/")
    self.siteurl(path)
  end

  #sugar for @siteurl
  def self.home()
    self.siteurl('/')
  end

  # Return hostname
  def self.hostname
    @@uri.host.downcase
  end

  # sugar for @hostname
  def self.host
    self.hostname
  end

  # Check if this is shadow
  def self.shadow?
    if @@shadow_hash.empty?
      return false
    else
      return true
    end
  end

  # Return ID of shadow container
  def self.shadowHash
    @@shadow_hash
  end

  # Return domain alias
  def self.domainAlias
    @@domain_alias
  end

  # Return OpenStruct @@user
  # User has attributes:
  # { :username, :password, :firstname, :lastname }
  def self.getUser
    if @@user
      return @@user
    else
      return nil
    end
  end

  # sugar for @getUser
  def self.user
    self.getUser
  end

  # Checks if user exists
  def self.user?
    ( self.getUser != nil )
  end

  # These functions are used for creating custom user for tests
  def self.createUser
    if @@user
      return @@user
    end

    # We can create tests which check the user name too
    firstname = ENV['WP_TEST_USER_FIRSTNAME'] || 'Seravo'
    lastname = ENV['WP_TEST_USER_LASTNAME'] || 'Test User'

    if ENV['WP_TEST_USER'] and ENV['WP_TEST_USER_PASS']
      username = ENV['WP_TEST_USER']
      password = ENV['WP_TEST_USER_PASS']
    elsif command? 'wp'
      # delete the old testbotuser if exists
      system "wp user delete testbotuser --yes > /dev/null 2>&1"
      username = "seravo-test"
      password = rand(36**32).to_s(36)
      system "wp user create #{username} no-reply@seravo.fi --user_pass=#{password} --role=administrator --first_name='#{firstname}' --last_name='#{lastname}' > /dev/null 2>&1"
      unless $?.success?
        system "wp user update #{username} --user_pass=#{password} --role=administrator --require=#{File.dirname(__FILE__)}/disable-wp-mail.php > /dev/null 2>&1"
      end
      # If we couldn't create user just skip the last test
      unless $?.success?
        return nil
      end
    end

    @@user = OpenStruct.new({ :username => username, :password => password, :firstname => firstname, :lastname => lastname })
    return @@user
  end

  # Set smaller privileges for the test user after tests
  # This is so that we don't have to create multiple users in production
  def self.lowerTestUserPrivileges
    unless @@user
      return false
    end

    # Use the same user multiple times without changing it if was from ENV
    if ENV['WP_TEST_USER']
      return true
    end

    system "wp user update #{@@user.username} --role=subscriber > /dev/null 2>&1"
    return true
  end

  private
  ##
  # Check site uri before each call
  # Use ENV WP_TEST_URL if possible
  # otherwise try with wp cli
  # otherwise use localhost
  ##
  def self.getUri
    if ENV['WP_TEST_URL']
      target_url = ENV['WP_TEST_URL']
    elsif command? 'wp' and `wp core is-installed`
      target_url = `wp option get home`.strip
    else
      puts "WARNING: Can't find configured site. Using 'http://localhost' instead."
      target_url = "http://localhost"
    end

    URI(target_url)
  end

  # Parse shadow hash from container id
  def self.getShadowHash
    if ENV['CONTAINER']
      return ENV['CONTAINER'].partition('_').last
    else
      return ""
    end
  end

  ##
  # Get domain alias for admin if used
  ##
  def self.getDomainAlias
    ENV['HTTPS_DOMAIN_ALIAS']
  end


  # Cache the parsed site uri here for other functions to use
  @@uri = getUri()

  # Check for container id as well
  @@shadow_hash = getShadowHash()

  # Check for domain alias
  @@domain_alias = getDomainAlias()
end
