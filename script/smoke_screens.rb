#!/usr/bin/env ruby
# HTTP smoke test: logs in and requests every screen, reporting non-200 responses.
require "net/http"
require "uri"
require "cgi"

BASE = ENV.fetch("QM_BASE", "http://127.0.0.1:3010")
USER = ENV.fetch("QM_USER", "admin")
PASS = ENV.fetch("QM_PASS", "admin123")

def http_get(path)
  uri = URI.join(BASE, path)
  req = Net::HTTP::Get.new(uri)
  req["Cookie"] = $cookies
  res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  store_cookies(res)
  res
end

def store_cookies(res)
  jar = res.get_fields("set-cookie").to_a
  return if jar.empty?

  pairs = jar.map { |c| c.split(";").first }
  existing = $cookies.split("; ").reject { |c| pairs.any? { |p| p.start_with?(c.split("=").first + "=") } }
  $cookies = (existing + pairs).join("; ")
end

def http_post(path, data = {})
  uri = URI.join(BASE, path)
  res = Net::HTTP.start(uri.hostname, uri.port) do |http|
    req = Net::HTTP::Post.new(uri)
    req["Cookie"] = $cookies
    req.set_form_data(data)
    res = http.request(req)
    store_cookies(res)
    res
  end
end

# The owner console can suspend a shop, which locks every login of that shop and
# makes all admin screens bounce to the sign-in page. Catch that here instead of
# reporting a wall of confusing failures.
if defined?(ActiveRecord::Base)
  stalled = Business.where(status: "suspended").pluck(:name)
  unless stalled.empty?
    warn "suspended business(es): #{stalled.join(", ")}"
    warn "reactivate from the owner console (/owner) or with: bin/rails runner 'Business.where(status: \"suspended\").update_all(status: \"active\")'"
    exit 2
  end
end

$cookies = ""
login_page = http_get("/login")
token = login_page.body[/name="authenticity_token" value="([^"]+)"/, 1]
login = http_post("/login", { "username" => USER, "password" => PASS, "authenticity_token" => token })
unless login.code == "302"
  warn "login failed (#{login.code}); aborting"
  exit 2
end

failures = []
paths = ARGV.empty? ? nil : ARGV

def get(path, token: false)
  res = http_get(path)
  token ? res.body.to_s[/name="authenticity_token" value="([^"]+)"/, 1] : res
end

TARGETS = [
  "/", "/sales", "/sales/new", "/purchases", "/purchases/new",
  "/customers", "/customers/new", "/suppliers", "/suppliers/new", "/agents", "/agents/new",
  "/products", "/products/new", "/categories", "/categories/new", "/brands", "/brands/new",
  "/stock", "/installments/collection", "/installments/roznamcha", "/installments/short-tracker",
  "/expenses", "/expenses/new", "/cash-book", "/accounts/chart", "/accounts/vouchers",
  "/accounts/vouchers/new", "/receipt-vouchers", "/payment-vouchers", "/pdc", "/transfers",
  "/closures", "/bookings", "/bookings/new", "/registration_trackings", "/quotations",
  "/quotations/new", "/vehicle_documents", "/credit_recoveries", "/accounts/journal",
  "/accounts/journal/new", "/qist-calculator", "/reports", "/settings/business", "/users",
  "/users/new", "/change-password", "/variants", "/variants/new", "/agent-commissions",
  "/agent-commissions/new", "/sales-list", "/purchase-list", "/stock-list"
].freeze

(paths || TARGETS).each do |path|

  res = get(path)
  status = res.code
  if status.to_i == 200
    puts "  ok   #{status} #{path}"
  else
    detail = res.body.to_s[/<h1[^>]*>(.*?)<\/h1>/m, 1].to_s.gsub(/\s+/, " ").strip
    failures << [path, status, detail]
    puts "  FAIL #{status} #{path} #{detail[0, 160]}"
  end
end

puts
if failures.empty?
  puts "ALL SCREENS OK"
else
  puts "#{failures.size} FAILURES"
  failures.each { |path, status, detail| puts "  #{status} #{path} — #{detail}" }
  exit 1
end