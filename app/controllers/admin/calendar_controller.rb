class Admin::CalendarController < Admin::BaseController
  def index
    @current_month = parse_month_param

    @prev_month = (@current_month - 1.month).strftime("%Y-%m")
    @next_month = (@current_month + 1.month).strftime("%Y-%m")

    @month_label = I18n.l(@current_month, format: "%B %Y")

    grid_start = @current_month.beginning_of_week   # Monday (Rails default)
    grid_end   = @current_month.end_of_month.end_of_week

    @artes = Arte.where(scheduled_on: grid_start..grid_end)
                 .includes(:client)
                 .order(:id)

    @artes_by_date = @artes.group_by(&:scheduled_on)
    @grid_dates    = (grid_start..grid_end).to_a
  end

  private

  def parse_month_param
    return Time.zone.today.beginning_of_month unless params[:month].present?
    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue Date::Error
    Time.zone.today.beginning_of_month
  end
end
