# frozen_string_literal: true

module Api::V1::Client::ArteSerializer
  def self.serialize(arte)
    responses = arte.association(:approval_responses).loaded? ? arte.approval_responses : []
    {
      id:                 arte.id,
      title:              arte.title,
      caption:            arte.caption,
      scheduled_on:       arte.scheduled_on,
      approval_deadline:  arte.approval_deadline,
      platform:           arte.platform,
      media_type:         arte.media_type,
      media_url:          resolve_media_url(arte),
      status:             arte.status,
      admin_reply:        arte.admin_reply,
      approval_responses: serialize_responses(responses)
    }
  end

  def self.serialize_collection(artes)
    artes.map { |a| serialize(a) }
  end

  private_class_method def self.resolve_media_url(arte)
    if arte.media_file.attached?
      arte.media_file.url
    else
      arte.external_url
    end
  end

  private_class_method def self.serialize_responses(responses)
    responses.map do |r|
      { id: r.id, decision: r.decision, comment: r.comment, responded_at: r.responded_at }
    end
  end
end
