class Client::ResponsesController < ClientController
  before_action :set_arte

  def create
    unless ApprovalResponse.decisions.key?(params.dig(:approval_response, :decision))
      return redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                         alert: "Resposta inválida."
    end

    Arte.transaction do
      locked_arte = @client.artes.lock.find(@arte.id)
      response = locked_arte.approval_responses.build(response_params)
      if response.save
        redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                    notice: flash_notice_for(response.decision)
      else
        redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                    alert: response.errors.full_messages.to_sentence
      end
    end
  end

  private

  def set_arte
    @arte = @client.artes.find(params[:arte_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to client_root_path(token: @client.access_token),
                alert: "Arte não encontrada."
  end

  def response_params
    params.require(:approval_response).permit(:decision, :comment)
  end

  def flash_notice_for(decision)
    decision == "approved" ? "Arte aprovada!" : "Pedido de alteração enviado."
  end
end
