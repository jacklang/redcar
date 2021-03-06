
When /^I (?:open|have opened) the file "([^"]+)"$/ do |filename|
  Redcar::OpenTabCommand.new(filename).do
end

When /^I save the EditTab$/ do
  When "I press \"Ctrl+S\""
end

When /^I save the EditTab as #{FeaturesHelper::STRING_RE}$/ do |filename|
  Redcar::SaveTabAs.new(filename).do
end
