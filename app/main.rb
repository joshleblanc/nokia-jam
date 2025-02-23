$gtk.disable_controller_config

# Logical canvas width and height
WIDTH = 1280
HEIGHT = 720

# Nokia screen dimensions
NOKIA_WIDTH = 84
NOKIA_HEIGHT = 48

# Determine best fit zoom level
ZOOM_WIDTH = (WIDTH / NOKIA_WIDTH).floor
ZOOM_HEIGHT = (HEIGHT / NOKIA_HEIGHT).floor
ZOOM = [ZOOM_WIDTH, ZOOM_HEIGHT].min

# Compute the offset to center the Nokia screen
OFFSET_X = (WIDTH - NOKIA_WIDTH * ZOOM) / 2
OFFSET_Y = (HEIGHT - NOKIA_HEIGHT * ZOOM) / 2

# Compute the scaled dimensions of the Nokia screen
ZOOMED_WIDTH = NOKIA_WIDTH * ZOOM
ZOOMED_HEIGHT = NOKIA_HEIGHT * ZOOM

PALLETTE = {
  primary: {
    r: 78,
    g: 94,
    b: 85
  },
  secondary: {
    r: 26,
    g: 32,
    b: 24
  },
}

STATUS_BAR_H = 12
MACHINE_SIZE = 16

MILL = {
  speed: 0,
  production: 0,
  level: 0,
  purchased: false
}

def boot(args)
  args.state = {
    level: 1,
    money: 0,
    time: 0,
    view: :room,
    confirm_open: false,
    selection: {
      x: 0,
      y: 0
    },
    mills: [
      [MILL.dup, MILL.dup],
      [MILL.dup, MILL.dup]
    ]
  }
end

def tick(args)
  # set the background color to black
  args.outputs.background_color = [0, 0, 0]

  # define a render target that represents the Nokia screen
  args.outputs[:nokia].w = 84
  args.outputs[:nokia].h = 48
  args.outputs[:nokia].background_color = PALLETTE[:secondary]

  args.state.nokia_mouse_position = {
    x: (args.inputs.mouse.x - OFFSET_X).idiv(ZOOM),
    y: (args.inputs.mouse.y - OFFSET_Y).idiv(ZOOM),
    w: 1,
    h: 1,
  }

  if args.state.view == :room
    handle_room_input(args)
    render_room_status_bar(args)
    render_room(args)
    # render_info_bar(args)
  end 

  if args.state.confirm_open
    render_confirm(args)
  end

  # render the game scaled to fit the screen
  args.outputs.sprites << {
    x: WIDTH / 2,
    y: HEIGHT / 2,
    w: ZOOMED_WIDTH,
    h: ZOOMED_HEIGHT,
    anchor_x: 0.5,
    anchor_y: 0.5,
    path: :nokia,
  }
end

def nokia 
  $args.outputs[:nokia]
end

def handle_room_input(args)
  if args.inputs.keyboard.key_down.left
    args.state.selection.x = (args.state.selection.x - 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.right
    args.state.selection.x = (args.state.selection.x + 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.up
    args.state.selection.y = (args.state.selection.y + 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.down
    args.state.selection.y = (args.state.selection.y - 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.space
    process_mill_select(args)
  end
end

def process_mill_select(args)
  mill = args.state.mills[args.state.selection.y][args.state.selection.x]
  if mill.purchased
  else
    confirm(args, "Do you want to buy a mill for 50 money?") do |result|
      if result
        mill.purchased = true
      end
    end
  end
end

def confirm(args, message, &block)
  args.state.confirm_message = message
  args.state.confirm_block = block
  args.state.confirm_open = true

  
  # block.call(true)
end

def render_confirm(args)
  nokia.primitives << {
    x: 4, y: 4,
    w: NOKIA_WIDTH - 8,
    h: NOKIA_HEIGHT - 8,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }

  nokia.primitives << { 
    x: 4, y: 4,
    w: NOKIA_WIDTH - 8,
    h: NOKIA_HEIGHT - 8,
    **PALLETTE[:primary],
    primitive_marker: :border
  }

  w,h = $gtk.calcstringbox(args.state.confirm_message, size_px: 6, font: "tiny.ttf")

  lines = []
  text = []
  args.state.confirm_message.split(" ").each do |word|
    ww,hh = $gtk.calcstringbox((text + [word]).join(" "), size_px: 6, font: "tiny.ttf")
    if ww >= NOKIA_WIDTH - 8
      lines << text.join(" ")
      text = [word]
    else 
      text << word
    end
  end

  lines << text.join(" ")

  lines.each_with_index do |line, y|
    nokia.primitives << {
      x: 6, y: (NOKIA_WIDTH - 8) / 2 - 4 - y * 6,
      text: line,
      size_px: 6,
      vertical_alignment_enum: 1,
      font: "tiny.ttf",
      **PALLETTE[:primary],
      primitive_marker: :label
    }
  end
end

def render_room(args)
  mills = args.state.mills
  mills.each_with_index do |row, y|
    row.each_with_index do |mill, x|
      nokia.primitives << {
        x: x * MACHINE_SIZE + (13 * (x + 1)),
        y: y * MACHINE_SIZE + 4,
        w: MACHINE_SIZE,
        h: MACHINE_SIZE,
        **PALLETTE[:secondary],
        primitive_marker: :border
      }

      nokia.primitives << {
        x: x * MACHINE_SIZE + (13 * (x + 1)),
        y: y * MACHINE_SIZE + 4,
        w: MACHINE_SIZE,
        h: MACHINE_SIZE,
        **PALLETTE[:primary],
        primitive_marker: :solid
      }

      if x == args.state.selection.x && y == args.state.selection.y
        nokia.primitives << {
          x: x * MACHINE_SIZE + 8 + (13 * x),
          y: y * MACHINE_SIZE + 10,
          w: 4,
          h: 4,
          **PALLETTE[:primary],
          primitive_marker: :solid
        }
      end
      
      if mill.purchased 

      else 
        x_pos = x * MACHINE_SIZE + (13 * (x + 1))
        y_pos = y * MACHINE_SIZE + 6
        
        nokia.primitives << {
          x: x_pos + 8, y: y_pos + 6,
          w: 16, h: 16,
          text: "$",
          size_px: 6,
          vertical_alignment_enum: 1,
          alignment_enum: 1,
          font: "tiny.ttf",
          **PALLETTE[:secondary],
          primitive_marker: :label
        }
      end
    end
  end
end

# def render_info_bar(args)
#   nokia.solids << {
#     x: 0, y: 0,
#     w: NOKIA_WIDTH,
#     h: 4,
#     **PALLETTE[:primary]
#   }

#   text = "Purchase Mill $100"

#   w, h = $gtk.calcstringbox(text, size_px: 6, font: "tiny.ttf")
#   nokia.labels << {
#     x: 1, y: h / 2,
#     w: NOKIA_WIDTH,
#     h: 4,
#     text: text,
#     size_px: 6,
#     vertical_alignment_enum: 1,
#     font: "tiny.ttf",
#     **PALLETTE[:secondary]
#   }
# end

def render_room_status_bar(args)
  nokia.primitives << { 
    x: 0, y: NOKIA_HEIGHT - STATUS_BAR_H,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  text = "$#{args.state.money} L:#{args.state.level} T:#{args.state.time}"

  w, h = $gtk.calcstringbox(text, size_px: 6, font: "tiny.ttf")
  nokia.primitives << {
    x: 1, y: NOKIA_HEIGHT - h,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    text: text,
    size_px: 6,
    vertical_alignment_enum: 1,
    font: "tiny.ttf",
    **PALLETTE[:secondary],
    primitive_marker: :label
  }
end 

def render_machine_status_bar(args)
  nokia.primitives << { 
    x: 0, y: NOKIA_HEIGHT - STATUS_BAR_H,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  text = "Mill lvl 2"

  w, h = $gtk.calcstringbox(text, size_px: 6, font: "tiny.ttf")
  nokia.primitives << {
    x: 1, y: NOKIA_HEIGHT - h,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    text: text,
    size_px: 6,
    vertical_alignment_enum: 1,
    font: "tiny.ttf",
    **PALLETTE[:secondary],
    primitive_marker: :label
  }
end