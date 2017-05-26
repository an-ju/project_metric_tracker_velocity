require "project_metric_tracker_velocity/version"
require 'faraday'
require 'json'

class ProjectMetricTrackerVelocity
  attr_reader :raw_data
  attr_reader :latest_iteration, :status

  def initialize(credentials, raw_data = nil)
    @project = credentials[:tracker_project]
    @conn = Faraday.new(url: 'https://www.pivotaltracker.com/services/v5')
    @conn.headers['Content-Type'] = 'application/json'
    @conn.headers['X-TrackerToken'] = credentials[:tracker_token]
    @raw_data = raw_data
  end

  def refresh
    @raw_data ||= iterations
    @image = @score = nil
  end

  def raw_data=(new)
    @raw_data = new
    @score = nil
    @image = nil
  end

  def score
    @raw_data ||= iterations
    synthesize
    @score ||= @status.has_key?(:accepted) ? (@status[:accepted].to_f / @sum_points) : 0.0
  end

  def image
    @raw_data ||= iterations
    synthesize
    @image ||= { chartType: 'tracker_velocity',
                 textTitle: 'Tracker Velocity',
                 data: process_hash }
  end

  def self.credentials
    %I[tracker_project tracker_token]
  end

  private

  def iterations
    JSON.parse(@conn.get("projects/#{@project}/iterations").body)
  end

  def synthesize
    @raw_data ||= iterations
    @latest_iteration = @raw_data.empty? ? { stories: [] } : @raw_data[-1]
    @sum_points = @latest_iteration['stories'].inject { |sum, elem| sum + (elem['estimate'] ? elem['estimate'] : 0) }
    states = @latest_iteration['stories'].group_by { |story| story['current_state'].to_sym }
    @status = {}
    states.each_pair do |key, val|
      @status[key] = val.inject { |sum, elem| sum + (elem['estimate'] ? elem['estimate'] : 0) }
    end
  end

  def process_hash
    { unscheduled: 0.0,
      unstarted: 0.0,
      started: 0.0,
      finished: 0.0,
      delivered: 0.0,
      accepted: 0.0,
      rejected: 0.0 }.update(@status)
  end
end
