require "project_metric_tracker_velocity/version"
require 'faraday'
require 'json'

class ProjectMetricTrackerVelocity
  attr_reader :raw_data

  def initialize(credentials, raw_data = nil)
    @project = credentials[:tracker_project]
    @conn = Faraday.new(url: 'https://www.pivotaltracker.com/services/v5')
    @conn.headers['Content-Type'] = 'application/json'
    @conn.headers['X-TrackerToken'] = credentials[:tracker_token]
    @raw_data = raw_data

    @max_iter = 0
  end

  def refresh
    @image = @score = nil
    @raw_data ||= stories
  end

  def raw_data=(new)
    @raw_data = new
    @score = nil
    @image = nil
  end

  def score
    @raw_data ||= stories
    synthesize
    @score ||= @velocity[@max_iter]
  end

  def image
    @raw_data ||= stories
    synthesize
    @image ||= { chartType: 'tracker_velocity_v2',
                 textTitle: 'Tracker Velocity',
                 data: @velocity }.to_json
  end

  def self.credentials
    %I[tracker_project tracker_token]
  end

  private

  def stories
    JSON.parse(@conn.get("projects/#{@project}/stories").body)
  end

  def synthesize
    @raw_data ||= stories
    iteration_data = @raw_data.map do |story|
      iter = get_iterations(story)
      story.update iteration: iter.nil? ? -1 : iter
    end

    @velocity = iteration_data.inject(Hash.new(0)) do |sum, story|
      if story['current_state'].eql? 'accepted'
        @max_iter = story[:iteration] if story[:iteration] > @max_iter
        sum[story[:iteration]] += story['estimate'].nil? ? 1 : story['estimate']
      end
      sum
    end
  end

  def get_iterations(story)
    iterations = story['labels'].map do |label|
      /^[i|I]ter[^0-9]*([0-9]).*$/ =~ label['name']
      $1.nil? ? nil : $1.to_i
    end
    iterations.reject(&:nil?).sort.last
  end
end
