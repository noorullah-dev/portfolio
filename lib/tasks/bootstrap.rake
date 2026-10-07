namespace :app do
  desc "Create a platform owner interactively without demo data"
  task create_owner: :environment do
    require "io/console"

    abort "Run this task in an interactive terminal." unless $stdin.tty?
    print "Owner username: "
    username = $stdin.gets&.strip
    abort "Username is required." if username.blank?
    abort "That username already exists." if User.exists?(["lower(username) = ?", username.downcase])

    print "Full name: "
    name = $stdin.gets&.strip
    password = $stdin.getpass("Password (at least 12 characters): ")
    confirmation = $stdin.getpass("Confirm password: ")
    abort "Password must contain at least 12 characters." if password.length < 12
    abort "Passwords do not match." unless password == confirmation

    User.create!(username: username, full_name: name, role: "owner", status: "active",
                 password: password, password_confirmation: confirmation,
                 must_change_password: false)
    puts "Platform owner created. Sign in and create your business from the owner console."
  end
end
