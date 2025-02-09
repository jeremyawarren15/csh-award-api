class AwardGeneratorService
  SUBJECTS = %w[Religion Math Science Latin Language_Arts History Geography Timeline].freeze

  ACHIEVEMENT_TITLES = {
    1 => 'Spectacular Specialist',
    2 => 'Whiz Kid',
    3 => 'Terrific Thinker',
    4 => 'Academic Athlete',
    5 => 'Extraordinary Expert',
    6 => 'Incredible Intellectual',
    7 => 'Emerging Einstein',
    8 => 'Super Scholar'
  }.freeze

  def initialize(csv_data, chapter_name, director_name, tour, year, showcase_date,
                generate_awards: true, generate_subject_certs: true, generate_tbg_certs: true)
    @csv_data = process_csv_data(csv_data)
    @chapter_name = chapter_name
    @director_name = director_name
    @tour = tour
    @year = year
    @showcase_date = showcase_date
    @generate_awards = generate_awards
    @generate_subject_certs = generate_subject_certs
    @generate_tbg_certs = generate_tbg_certs

    Rails.logger.debug "=== Initialize ==="
    Rails.logger.debug "Students: #{@csv_data.inspect}"
    Rails.logger.debug "Chapter: #{@chapter_name.inspect}"
    Rails.logger.debug "Director: #{@director_name.inspect}"
    Rails.logger.debug "Tour: #{@tour.inspect}"
    Rails.logger.debug "Year: #{@year.inspect}"
    Rails.logger.debug "Showcase Date: #{@showcase_date.inspect}"
  end

  def generate
    Rails.logger.debug "=== Generate Start ==="
    Rails.logger.debug "Generate Awards Flag: #{@generate_awards}"
    Rails.logger.debug "Generate Subject Certs Flag: #{@generate_subject_certs}"

    return nil unless @generate_awards || @generate_subject_certs

    begin
      template_path = Rails.root.join('app/views/awards/certificate.html.erb')
      Rails.logger.debug "Template path: #{template_path}"
      Rails.logger.debug "Template exists? #{File.exist?(template_path)}"

      certificates = []

      # Generate subject certificates if enabled
      if @generate_subject_certs
        certificates += generate_subject_certificates
      end

      return nil if certificates.empty?

      html_content = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            @media print {
              .certificate-container {
                page-break-after: always;
              }
              .certificate-container:last-child {
                page-break-after: avoid;
              }
            }
          </style>
        </head>
        <body>
          #{certificates.join("<div style='page-break-before: always;'></div>")}
        </body>
        </html>
      HTML

      Rails.logger.debug "=== PDF Generation Start ==="
      pdf = WickedPdf.new.pdf_from_string(
        html_content,
        {
          page_size: 'Letter',
          orientation: 'Landscape',
          margin: {
            top: 0,
            bottom: 0,
            left: 0,
            right: 0
          },
          print_media_type: true,
          encoding: 'UTF-8',
          debug: true
        }
      )
      Rails.logger.debug "=== PDF Generation Complete ==="

      # Write both HTML and PDF for debugging
      Rails.root.join('tmp').mkpath
      File.write(Rails.root.join('tmp', 'debug.html'), html_content)
      File.write(Rails.root.join('tmp', 'debug.pdf'), pdf, mode: 'wb')

      Rails.logger.debug "Debug files written to tmp/debug.html and tmp/debug.pdf"

      pdf
    rescue => e
      Rails.logger.error "=== Error in Generate ==="
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end

  private

  def process_csv_data(csv_data)
    csv_data.map do |row|
      # Convert the row to a hash if it isn't already
      row_hash = row.to_h

      # Count subjects that are TRUE
      subject_count = SUBJECTS.count do |subject|
        row_hash[subject]&.upcase == 'TRUE'
      end

      # Add the subject count and achievement title to the row data
      row_hash['subject_count'] = subject_count
      row_hash['achievement_title'] = ACHIEVEMENT_TITLES[subject_count]
      row_hash
    end
  end

  def load_logo_base64
    # Implement loading and converting logo to base64
    logo_path = Rails.root.join('app', 'assets', 'images', 'logo.jpg')
    Base64.strict_encode64(File.read(logo_path))
  rescue => e
    Rails.logger.error "Failed to load logo: #{e.message}"
    ''
  end

  def format_date(date_string)
    date = Date.parse(date_string)
    day_ordinal = date.day.ordinalize
    date.strftime("#{day_ordinal} of %B, %Y")
  end

  def generate_subject_certificates
    certificates = []
    @csv_data.each do |student|
      completed_subjects = SUBJECTS.select { |subject| student[subject]&.upcase == 'TRUE' }

      if completed_subjects.empty?
        # Generate participation certificate
        certificates << ActionController::Base.new.render_to_string(
          template: "awards/participation",
          layout: false,
          locals: {
            logo: load_logo_base64,
            student_name: student['Name'] || student['name'],
            tour: @tour,
            year: @year,
            showcaseDate: format_date(@showcase_date),
            directorsName: @director_name,
            chapterName: @chapter_name
          }
        )
      else
        # Generate achievement certificate
        subjects_text = completed_subjects.join(', ').gsub('_', ' ')
        certificates << ActionController::Base.new.render_to_string(
          template: "awards/certificate",
          layout: false,
          locals: {
            logo: load_logo_base64,
            student_name: student['Name'] || student['name'],
            tour: @tour,
            year: @year,
            showcaseDate: format_date(@showcase_date),
            directorsName: @director_name,
            chapterName: @chapter_name,
            title: student['achievement_title'],
            subjects: subjects_text
          }
        )
      end
    end
    certificates
  end
end