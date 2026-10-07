# Adds `optional: true` to belongs_to declarations whose foreign key column
# allows NULL, and tidies the generated formatting. Safe to re-run.
#
#   bin/rails runner script/fix_optional_belongs_to.rb

Rails.application.eager_load!

MODELS_DIR = Rails.root.join("app/models")
tables = ActiveRecord::Base.connection.tables

changed = []

MODELS_DIR.glob("*.rb").each do |file|
  source = file.read
  updated = source.dup

  updated.scan(/^  belongs_to :(\w+)(.*)$/) do |name, rest|
    options = rest.sub(/\A,\s*/, "")
    next if options.include?("optional:")
    next if rest.include?("through:") || rest.include?("polymorphic")

    table = file.basename(".rb").to_s.pluralize
    next unless tables.include?(table)

    column = ActiveRecord::Base.connection.columns(table).find { |c| c.name == "#{name}_id" }
    next if column.nil? || !column.null

    replacement = options.empty? ? ", optional: true" : ", #{options}, optional: true"
    updated = updated.sub(/^  belongs_to :#{name}#{Regexp.escape(rest)}$/, "  belongs_to :#{name}#{replacement}")
  end

  updated = updated.gsub(/\A(class .*< ApplicationRecord)\n\n/, "\\1\n")
  updated = updated.gsub(/\n\nend\n\z/, "\nend\n")
  updated = updated.gsub(/\n\n\n+/, "\n\n")

  if updated != source
    file.write(updated)
    changed << file.basename.to_s
  end
end

puts "updated #{changed.size} models: #{changed.sort.join(", ")}"