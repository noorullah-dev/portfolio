# Pin npm packages by running ./bin/importmap
pin "application"

# Hotwire Native shell: Turbo drives every navigation inside the native app.
# Served from the turbo-rails gem, so no CDN or npm install is needed.
pin "turbo", to: "turbo.min.js"
pin "native"
