test_name "#6857: redact password hashes when applying in noop mode"

require 'puppet/acceptance/common_utils'
extend Puppet::Acceptance::CommandUtils

hosts_to_test = agents.reject do |agent|
  if agent['platform'].match /(?:ubuntu|centos|debian|el-|fedora)/
    result = on(agent, "#{ruby_command(agent)} -e \"require 'shadow' or raise\"", :acceptable_exit_codes => [0,1])
    result.exit_code != 0
  else
    # Non-linux platforms do not rely on ruby-libshadow for password management
    # and so we don't reject them from testing
    false
  end
end
skip_test "No suitable hosts found" if hosts_to_test.empty?

username = "pl#{rand(99999).to_i}"

teardown do
  step "Teardown: Ensure test user is removed"
  hosts_to_test.each do |host|
    on agent, puppet('resource', 'user', username, 'ensure=absent')
    on agent, puppet('resource', 'group', username, 'ensure=absent')
  end
end

adduser_manifest = <<MANIFEST
user { '#{username}':
  ensure   => 'present',
  password => 'apassword',
}
MANIFEST

changepass_manifest = <<MANIFEST
user { '#{username}':
  ensure   => 'present',
  password => 'newpassword',
  noop     => true,
}
MANIFEST

apply_manifest_on(hosts_to_test, adduser_manifest )
apply_manifest_on(hosts_to_test, changepass_manifest ) do |result|
  assert_match( /current_value \[old password hash redacted\], should be \[new password hash redacted\]/ , "#{result.host}: #{result.stdout}" )
end
