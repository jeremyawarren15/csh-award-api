module Api
  module V1
    class AwardsController < ApplicationController
      def generate
        unless params[:csv_file] && params[:chapter_name] && params[:director_name] &&
               params[:tour] && params[:year] && params[:showcase_date]
          render json: { error: 'All fields are required' },
                 status: :bad_request
          return
        end

        begin
          # Ensure headers are symbolized and cleaned
          csv_data = CSV.parse(
            params[:csv_file].read,
            headers: true,
            header_converters: ->(h) { h.strip.gsub(/\s+/, '_') }
          )

          Rails.logger.debug "CSV Headers: #{csv_data.headers.inspect}"
          Rails.logger.debug "CSV Data: #{csv_data.inspect}"
          Rails.logger.debug "Chapter Name: #{params[:chapter_name]}"
          Rails.logger.debug "Director Name: #{params[:director_name]}"
          Rails.logger.debug "Tour: #{params[:tour]}"
          Rails.logger.debug "Year: #{params[:year]}"
          Rails.logger.debug "Showcase Date: #{params[:showcase_date]}"
          Rails.logger.debug "Generate Awards: #{params[:generate_awards]}"
          Rails.logger.debug "Generate Subject Certs: #{params[:generate_subject_certs]}"
          Rails.logger.debug "Generate TBG Certs: #{params[:generate_tbg_certs]}"

          pdf_data = AwardGeneratorService.new(
            csv_data,
            params[:chapter_name],
            params[:director_name],
            params[:tour],
            params[:year],
            params[:showcase_date],
            generate_awards: params[:generate_awards] == 'true',
            generate_subject_certs: params[:generate_subject_certs] == 'true',
            generate_tbg_certs: params[:generate_tbg_certs] == 'true'
          ).generate

          if pdf_data.nil? || pdf_data.empty?
            render json: { error: 'No certificates were generated. Please check your CSV data and certificate options.' },
                   status: :unprocessable_entity
            return
          end

          send_data(
            pdf_data,
            filename: "awards.pdf",
            type: "application/pdf",
            disposition: "attachment"
          )
        rescue CSV::MalformedCSVError
          render json: { error: 'Invalid CSV file. Please ensure all required columns are present.' },
                 status: :unprocessable_entity
        rescue StandardError => e
          Rails.logger.error "PDF Generation Error: #{e.message}\n#{e.backtrace.join("\n")}"
          render json: { error: e.message }, status: :internal_server_error
        end
      end
    end
  end
end