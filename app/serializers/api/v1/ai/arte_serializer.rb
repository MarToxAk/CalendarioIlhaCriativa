# frozen_string_literal: true

module Api::V1::Ai::ArteSerializer
  def self.serialize(arte)
    {
      id:                arte.id,
      title:             arte.title,
      caption:           arte.caption,
      scheduled_on:      arte.scheduled_on,
      approval_deadline: arte.approval_deadline,
      platform:          arte.platform,
      media_type:        arte.media_type,
      status:            arte.status,
      client_id:         arte.client_id,
      media_url:         resolve_media_url(arte),
      media_source_type: arte.media_file.attached? ? "upload" : (arte.external_url.present? ? "link" : nil),
      created_at:        arte.created_at,
      updated_at:        arte.updated_at
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
end
