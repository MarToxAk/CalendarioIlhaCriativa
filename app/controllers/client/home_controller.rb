class Client::HomeController < ClientController
  def index
    @current_month = parse_month_param

    @prev_month = (@current_month - 1.month).strftime("%Y-%m")
    @next_month = (@current_month + 1.month).strftime("%Y-%m")
    @month_label = I18n.l(@current_month, format: "%B %Y")

    grid_start = @current_month.beginning_of_week   # Monday (Rails default)
    grid_end   = @current_month.end_of_month.end_of_week

    @artes = @client.artes
                    .where(scheduled_on: grid_start..grid_end)
                    .includes(media_file_attachment: :blob)
                    .order(:scheduled_on)

    @artes_by_date = @artes.group_by(&:scheduled_on)

    artes_do_mes = @artes.select { |a|
      a.scheduled_on.month == @current_month.month &&
        a.scheduled_on.year == @current_month.year
    }
    @summary = {
      total:            artes_do_mes.count,
      approved:         artes_do_mes.count { |a| a.status.to_s == "approved" },
      pending:          artes_do_mes.count { |a| %w[pending revised].include?(a.status.to_s) },
      change_requested: artes_do_mes.count { |a| a.status.to_s == "change_requested" }
    }

    @grid_dates    = (grid_start..grid_end).to_a
  end

  private

  def parse_month_param
    return Date.today.beginning_of_month unless params[:month].present?
    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue Date::Error
    Date.today.beginning_of_month
  end
end
