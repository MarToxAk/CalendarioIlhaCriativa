module ApplicationHelper
  include Pagy::Frontend

  def client_color(client)
    palette = [
      { bg: "bg-[#F0FDF4]", text: "text-[#14A958]" },  # verde
      { bg: "bg-[#EFF6FF]", text: "text-[#2563EB]" },  # azul
      { bg: "bg-[#FAF5FF]", text: "text-[#7C3AED]" },  # roxo
      { bg: "bg-[#FFF7ED]", text: "text-[#EA580C]" },  # laranja
      { bg: "bg-[#FFF0F3]", text: "text-[#E11D48]" },  # rosa
      { bg: "bg-[#F0FDFA]", text: "text-[#0D9488]" },  # teal
      { bg: "bg-[#FEFCE8]", text: "text-[#CA8A04]" },  # amarelo
      { bg: "bg-[#EEF2FF]", text: "text-[#4F46E5]" }  # índigo
    ]
    palette[client.id % palette.size]
  end

  # Returns Tailwind ring classes for the given arte's status.
  # Hex values are kept in sync with STATUS_MAP in arte_preview_controller.js.
  # pending has no ring (neutral/initial state).
  def arte_status_ring_class(arte)
    if arte.approved?
      "ring-2 ring-inset ring-[#14A958]"
    elsif arte.change_requested?
      "ring-2 ring-inset ring-[#EE3537]"
    elsif arte.revised?
      "ring-2 ring-inset ring-[#475569]"
    else
      ""
    end
  end

  def brazilian_holiday_for(date)
    BrazilianHolidays.for(date.year)[date]
  end
end
