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
      { bg: "bg-[#EEF2FF]", text: "text-[#4F46E5]" },  # índigo
    ]
    palette[client.id % palette.size]
  end

  def brazilian_holiday_for(date)
    BrazilianHolidays.for(date.year)[date]
  end
end
