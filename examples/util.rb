
module CirconusUtil

  def cid2int(cid)
    return cid.split('/').last.to_i
  end

  def do_update_check_bundle(data)
    search_check_bundle = @c.list_check_bundle({'display_name' => data['display_name']})
    existing = false
    if search_check_bundle.any? # already exists...
      existing = true
      r = @c.update_check_bundle(search_check_bundle.first['_cid'],data)
    else
      r = @c.add_check_bundle(data)
    end
    if not r.nil? then
      pp r
      print "Success (#{existing ? 'updating' : 'adding'} #{data['display_name']})\n"
    end
  end

  def do_update_graph(data)
    search_graphs = @c.search_graph(data['title'],'title')
    existing = false
    if search_graphs.any? # already exists...
      existing = true
      r = @c.update_graph(search_graphs.first['_cid'],data)
    else
      r = @c.add_graph(data)
    end
    if not r.nil? then
      pp r
      print "Success (#{existing ? 'updating' : 'adding'} #{data['title']})\n"
    end
  end

  def get_composite(options)
    return get_composite_stub().merge(options)
  end
  def get_guide(options)
    return get_guide_stub().merge(options)
  end
  def get_data(options)
    return get_data_stub().merge(options)
  end
  def get_dp(options)
    return get_dp_stub().merge(options)
  end

  def get_composite_stub()
    return {
      "name"=>"",
      "axis"=>"l",
      "stack"=>nil,
      "legend_formula"=>"=ceil(VAL)",
      "color"=>"#33aa33",
      "data_formula"=>"",
      "hidden"=>false
    }
  end

  def get_guide_stub()
    return {
      "data_formula"=>"",
      "name"=>"",
      "color"=>"#3a3aea",
      "hidden"=>false,
      "legend_formula"=>"=ceil(VAL)"
    }
      #"color"=>"#ea3a92",
  end

  def get_data_stub()
    return {
     "access_keys"=>[],
     "composites"=>[],
     "guides"=>[],
     "datapoints"=>[],
     "max_left_y"=>nil,
     "max_right_y"=>nil,
     "min_left_y"=>nil,
     "min_right_y"=>nil,
     "style"=>"area",
     "title"=>nil,
    }
  end

  def get_dp_stub()
    return {
      "axis"=>"l",
      "stack"=>nil,
      "metric_type"=>"numeric",
      "data_formula"=>nil,
      "name"=>nil,
      "derive"=>"counter",
      "metric_name"=>nil,
      "color"=>nil,
      "check_id"=>nil,
      "legend_formula"=>nil,
      "hidden"=>false
    }
  end

  # Generate hues of a particular variety at random (or just generate a random color altogether)
  def get_rand_rgb(hue='')
    r = rand
    g = rand
    b = rand
    case hue
    when 'red'
      r = (r * 125) + 130
      g = (g * 100) + 100
      b = g
    when 'orange'
      r = (r * 55) + 200
      g = (g * 50) + 150
      b = (b * 50) + 100
    when 'yellow'
      r = (r * 55) + 200
      g = r
      b = (b * 150)
    when 'green'
      r = (r * 150)
      g = (g * 125) + 120
      b = r
    when 'blue'
      r = (r * 150)
      g = r
      b = (b * 125) + 120
    when 'purple'
      r = (g * 55) + 200
      g = (b * 150)
      b = r
    else
      r = r * 256
      g = g * 256
      b = b * 256
    end
    return sprintf("#%02x%02x%02x",r,g,b)
  end

  # No SUM(*) is available, so we have to generate a formula ourselves:
  # Generate a total formula =A+B+C...... using the number of datapoints
  def get_total_formula(npoints)
    i = 0
    formula = "="
    a = 'A'..'ZZZZ'
    a.each do |x|
      i += 1
      formula += x
      break if i >= npoints
      formula += "+"
    end
    return formula
  end
  def get_average_formula(npoints, step=1, offset=0)
    npoints = npoints / step
    i = 0
    formula = "=("
    a = 'A'..'ZZZZ'
    a.each_with_index do |x, index|
      next unless (index - offset) % step == 0
      i += 1
      formula += x
      break if i >= npoints
      formula += "+"
    end
    formula += ")/#{npoints}"
    return formula
  end

end
