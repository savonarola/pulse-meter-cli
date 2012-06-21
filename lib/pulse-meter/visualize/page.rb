module PulseMeter
  module Visualize
    class Page
      attr_reader :widgets
      attr_reader :title
      attr_reader :gchart_options

      def initialize(args) 
        raise ArgumentError unless args.respond_to?('[]')
        @title = args[:title] or raise ArgumentError, ":title not specified"
        @widgets = args[:widgets] or raise ArgumentError, ":widgets not specified"
        @gchart_options = args[:gchart_options] or raise ArgumentError, ":gchart_options not specified"
      end

      def widget_data(widget_id, opts = {})
        widgets[widget_id].data(opts).merge(id: widget_id + 1)
      end

      def widget_datas
        res = []
        widgets.each_with_index do |w, i|
          res << w.data.merge(id: i + 1)
        end
        res
      end

    end
  end
end

