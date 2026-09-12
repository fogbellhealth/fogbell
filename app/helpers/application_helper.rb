module ApplicationHelper
  def manifest = @manifest ||= Fogbell::Review::Manifest.default
end
