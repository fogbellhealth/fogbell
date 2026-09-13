# Fogbell visual system — see design_handoff_fogbell/README.md. Four glyph families, never
# mixed: triangle = time, circle = verdict, square = rule provenance, diamond = data origin. Every
# badge is shape + label; color is never the only signal.
module DesignSystemHelper
  GLYPH_CLASSES = {
    triangle: "inline-block w-0 h-0 border-x-[5px] border-x-transparent border-b-[9px] border-b-current",
    circle_filled: "inline-block w-[9px] h-[9px] rounded-full bg-current",
    circle_half: "inline-block w-[9px] h-[9px] rounded-full border-[1.5px] border-current bg-[linear-gradient(90deg,currentColor_50%,transparent_50%)]",
    circle_hollow: "inline-block w-[9px] h-[9px] rounded-full border-2 border-current",
    circle_dashed: "inline-block w-[9px] h-[9px] rounded-full border-[1.5px] border-dashed border-current",
    square_filled: "inline-block w-2 h-2 bg-current",
    square_outline: "inline-block w-2 h-2 border-[1.5px] border-current",
    square_dashed: "inline-block w-2 h-2 border-[1.5px] border-dashed border-current",
    diamond: "inline-block w-2 h-2 border-[1.5px] border-current rotate-45"
  }.freeze

  BADGE_BASE = "inline-flex items-center gap-1.5 rounded px-2 py-1 text-xs font-semibold"

  # kind => [extra classes, glyph, default label]
  BADGES = {
    "closing" => [ "bg-closing text-white", :triangle, nil ],
    "closes_days" => [ "border border-rule text-ink", :triangle, nil ],
    "closed" => [ "border border-rule text-muted", nil, nil ],
    "supported" => [ "bg-supported text-white", :circle_filled, "Supported" ],
    "partial" => [ "border border-ink text-ink", :circle_half, "Partial" ],
    "unsupported" => [ "border border-closing text-closing", :circle_hollow, "Not supported" ],
    "verified" => [ "bg-window text-ink", :square_filled, "Verified" ],
    "pending" => [ "border border-dashed border-muted text-body", :square_outline, "Pending review" ],
    "unreviewed" => [ "border border-dashed border-faint text-muted", :square_dashed, "Unreviewed" ],
    "synthetic" => [ "border border-rule text-meta font-medium", :diamond, "Synthetic data" ],
    "provisional" => [ "border border-rule text-meta font-medium", :square_outline, "Provisional" ]
  }.freeze

  def glyph(kind)
    tag.span("", class: GLYPH_CLASSES.fetch(kind), aria: { hidden: true })
  end

  # kind: one of BADGES.keys. label: override the default (required for "closing"/"closes_days"/"closed").
  def badge(kind, label: nil)
    extra, glyph_kind, default_label = BADGES.fetch(kind.to_s)
    text = label || default_label
    content_tag(:span, class: "#{BADGE_BASE} #{extra}") do
      safe_join([ (glyph(glyph_kind) if glyph_kind), text ].compact)
    end
  end

  # Maps a Check result's verdict status to its badge kind.
  def verdict_badge(status)
    kind = { "supported" => "supported", "partial" => "partial", "unsupported" => "unsupported", "not_applicable" => "unreviewed" }.fetch(status, "unreviewed")
    label = status == "not_applicable" ? "Not applicable" : nil
    badge(kind, label: label)
  end

  # Maps an item's effective_review_status (unreviewed/pending/in_review/verified/disputed) to a badge kind.
  def provenance_badge(status)
    case status
    when "verified" then badge("verified")
    when "pending" then badge("pending")
    when "disputed" then badge("unsupported", label: "Disputed")
    else badge("unreviewed")
    end
  end

  # "Closes tomorrow"/"Closes today" (closing, <=1 day), "Closes in N days" (outline), "Closed <date>" (past).
  def deadline_badge(days_remaining, closed: false, past_date: nil)
    return badge("closed", label: "Closed #{past_date&.strftime('%b %-d')}") if closed

    if days_remaining <= 1
      badge("closing", label: days_remaining <= 0 ? "Closes today" : "Closes tomorrow")
    else
      badge("closes_days", label: "Closes in #{days_remaining} days")
    end
  end

  PRIMARY_BUTTON = "whitespace-nowrap rounded bg-ink px-3.5 py-2 text-[13px] font-semibold text-white hover:bg-body focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink"
  SECONDARY_BUTTON = "whitespace-nowrap rounded border border-rule bg-white px-3 py-2 text-[13px] font-semibold text-ink hover:bg-ground focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink"

  def primary_button(text, path, **opts)
    link_to text, path, **opts, class: [ PRIMARY_BUTTON, opts[:class] ].compact.join(" ")
  end

  def secondary_button(text, path, **opts)
    link_to text, path, **opts, class: [ SECONDARY_BUTTON, opts[:class] ].compact.join(" ")
  end
end
