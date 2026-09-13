# Guards the review queue: only rulebook-domain users (verifier/staff) may reach it. A facility
# user never sees another operator's rules-review work, and — the more important direction — a
# rulebook-domain user's session is never the one that can touch resident data (see
# FacilityAreaPolicy for that side of the boundary).
class RulebookAreaPolicy < ApplicationPolicy
  %i[index? show? create? questions?].each { |query| define_method(query) { user&.rulebook_domain? || false } }
end
