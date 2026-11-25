# frozen_string_literal: true

module WMX
    VERSION_MAJOR = 0
    VERSION_MINOR = 3
    FRAME_MAGIC   = 0x574D5830
    HEADER_BYTES  = 16
    FIXED_SCALE   = 10_000
  
    OK          = 0
    ERR_NOMEM   = 1
    ERR_IO      = 2
    ERR_BOUNDS  = 3
    ERR_INVALID = 4
  
    STATUS_NAMES = {
      OK          => 'WMX_OK',
      ERR_NOMEM   => 'WMX_ERR_NOMEM',
      ERR_IO      => 'WMX_ERR_IO',
      ERR_BOUNDS  => 'WMX_ERR_BOUNDS',
      ERR_INVALID => 'WMX_ERR_INVALID'
    }.freeze
  
    module LangTag
      UNKNOWN = 0
      PASCAL  = 1
      FORTRAN = 2
      COBOL   = 3
      SQL     = 4
      RUBY    = 5
      RUST    = 6
      CPP     = 7
      C       = 8
  
      NAMES = {
        UNKNOWN => 'UNKNOWN',
        PASCAL  => 'PASCAL',
        FORTRAN => 'FORTRAN',
        COBOL   => 'COBOL',
        SQL     => 'SQL',
        RUBY    => 'RUBY',
        RUST    => 'RUST',
        CPP     => 'CPP',
        C       => 'C'
      }.freeze
  
      def self.name_for(tag)
        NAMES.fetch(tag, "CUSTOM(#{tag})")
      end
    end
  
    FNV_OFFSET_32 = 0x811C9DC5
    FNV_PRIME_32  = 0x01000193
    MASK_32       = 0xFFFFFFFF
  
    module_function
  
    def target_platform
      plat = RUBY_PLATFORM.to_s
      case plat
      when /darwin/i  then 'macOS (Darwin Native)'
      when /freebsd/i then 'FreeBSD Native'
      when /openbsd/i then 'OpenBSD Native'
      when /netbsd/i  then 'NetBSD Native'
      when /linux/i   then 'Linux Native'
      else plat
      end
    end
  
    def fnv1a_32(bytes)
      data = bytes.to_s.b
      hash = FNV_OFFSET_32
      data.each_byte do |b|
        hash ^= b
        hash = (hash * FNV_PRIME_32) & MASK_32
      end
      hash
    end
  
    def secure_mem_equal?(a, b)
      ba = a.to_s.b
      bb = b.to_s.b
      return false unless ba.bytesize == bb.bytesize
  
      diff = 0
      ba.bytesize.times do |i|
        diff |= (ba.getbyte(i) ^ bb.getbyte(i))
      end
      diff.zero?
    end
  
    def pack_frame(lang_tag, payload, flags = 0)
      raw = payload.to_s.b
      raise ArgumentError, 'Payload exceeds UInt32 max' if raw.bytesize > MASK_32
  
      checksum = fnv1a_32(raw)
      header = [
        FRAME_MAGIC,
        lang_tag & 0xFFFF,
        flags & 0xFFFF,
        raw.bytesize,
        checksum
      ].pack('L<S<S<L<L<')
  
      raise "Header size mismatch: #{header.bytesize}" unless header.bytesize == HEADER_BYTES
  
      header + raw
    end
  
    def unpack_frame(buf)
      raw = buf.to_s.b
      return [ERR_INVALID, 0, 0, ''.b] if raw.bytesize < HEADER_BYTES
  
      magic, lang_tag, flags, payload_len, expected_sum = raw.byteslice(0, HEADER_BYTES).unpack('L<S<S<L<L<')
      return [ERR_INVALID, lang_tag, flags, ''.b] unless magic == FRAME_MAGIC
  
      available = raw.bytesize - HEADER_BYTES
      return [ERR_BOUNDS, lang_tag, flags, ''.b] if available < payload_len
  
      payload = raw.byteslice(HEADER_BYTES, payload_len)
      actual_sum = fnv1a_32(payload)
      return [ERR_INVALID, lang_tag, flags, ''.b] unless actual_sum == expected_sum
  
      [OK, lang_tag, flags, payload]
    end
  
    def hex_dump(bytes, width = 16)
      raw = bytes.to_s.b
      lines = []
      offset = 0
      while offset < raw.bytesize
        chunk = raw.byteslice(offset, width)
        hex_part = chunk.bytes.map { |b| format('%02X', b) }.join(' ').ljust(width * 3 - 1)
        ascii_part = chunk.bytes.map { |b| (b >= 32 && b <= 126) ? b.chr : '.' }.join
        lines << format('%08X  %s  |%s|', offset, hex_part, ascii_part)
        offset += width
      end
      lines.join("\n")
    end
  
    class Fixed4
      include Comparable
  
      attr_reader :scaled
  
      def initialize(scaled_int)
        @scaled = Integer(scaled_int)
      end
  
      def self.parse(str)
        s = str.to_s.strip
        raise ArgumentError, 'Empty fixed-point string' if s.empty?
  
        neg = false
        if s.start_with?('-')
          neg = true
          s = s[1..]
        elsif s.start_with?('+')
          s = s[1..]
        end
  
        raise ArgumentError, "Invalid fixed-point literal: #{str.inspect}" unless s.match?(/\A\d+(\.\d+)?\z/)
  
        whole_str, frac_str = s.split('.', 2)
        whole = whole_str.to_i
        frac_padded = (frac_str || '').ljust(4, '0')[0, 4].to_i
        total = whole * FIXED_SCALE + frac_padded
        total = -total if neg
        new(total)
      end
  
      def +(other)
        Fixed4.new(@scaled + coerce_scaled(other))
      end
  
      def -(other)
        Fixed4.new(@scaled - coerce_scaled(other))
      end
  
      def *(other)
        Fixed4.new((@scaled * coerce_scaled(other)) / FIXED_SCALE)
      end
  
      def /(other)
        denom = coerce_scaled(other)
        raise ZeroDivisionError, 'Fixed4 division by zero' if denom.zero?
  
        Fixed4.new((@scaled * FIXED_SCALE) / denom)
      end
  
      def <=>(other)
        @scaled <=> coerce_scaled(other)
      end
  
      def to_s
        sign = @scaled < 0 ? '-' : ''
        abs_val = @scaled.abs
        whole = abs_val / FIXED_SCALE
        frac = abs_val % FIXED_SCALE
        format('%s%d.%04d', sign, whole, frac)
      end
  
      def to_cobol_pic
        sign = @scaled < 0 ? '-' : '+'
        format('%s%018d', sign, @scaled.abs)
      end
  
      private
  
      def coerce_scaled(other)
        other.is_a?(Fixed4) ? other.scaled : Integer(other) * FIXED_SCALE
      end
    end
  
    class RingBuffer
      attr_reader :capacity, :size
  
      def initialize(capacity = 64)
        raise ArgumentError, 'Capacity must be positive' if capacity <= 0
  
        @capacity = capacity
        @storage = Array.new(capacity)
        @head = 0
        @tail = 0
        @size = 0
      end
  
      def empty?
        @size.zero?
      end
  
      def full?
        @size == @capacity
      end
  
      def push(item)
        return WMX::ERR_BOUNDS if full?
  
        @storage[@tail] = item
        @tail = (@tail + 1) % @capacity
        @size += 1
        WMX::OK
      end
  
      def pop
        return [WMX::ERR_INVALID, nil] if empty?
  
        item = @storage[@head]
        @storage[@head] = nil
        @head = (@head + 1) % @capacity
        @size -= 1
        [WMX::OK, item]
      end
  
      def peek
        return nil if empty?
  
        @storage[@head]
      end
  
      def clear
        @storage.fill(nil)
        @head = 0
        @tail = 0
        @size = 0
        WMX::OK
      end
  
      def to_a
        result = []
        idx = @head
        @size.times do
          result << @storage[idx]
          idx = (idx + 1) % @capacity
        end
        result
      end
    end
  
    class RecordTable
      attr_reader :columns, :rows
  
      def initialize(columns)
        raise ArgumentError, 'Columns cannot be empty' if columns.nil? || columns.empty?
  
        @columns = columns.map(&:to_s)
        @rows = []
      end
  
      def add_row(values)
        vals = Array(values)
        raise ArgumentError, "Expected #{@columns.size} values, got #{vals.size}" unless vals.size == @columns.size
  
        @rows << vals.map(&:to_s)
        @rows.size - 1
      end
  
      def render_ascii
        widths = @columns.each_with_index.map do |col, idx|
          max_cell = @rows.map { |r| r[idx].length }.max || 0
          [col.length, max_cell].max
        end
  
        border = '+' + widths.map { |w| '-' * (w + 2) }.join('+') + '+'
        header = '| ' + @columns.each_with_index.map { |c, i| c.ljust(widths[i]) }.join(' | ') + ' |'
  
        body = @rows.map do |row|
          '| ' + row.each_with_index.map { |cell, i| cell.ljust(widths[i]) }.join(' | ') + ' |'
        end
  
        ([border, header, border] + body + [border]).join("\n")
      end
  
      def render_csv
        lines = [@columns.map { |c| escape_csv(c) }.join(',')]
        @rows.each do |row|
          lines << row.map { |cell| escape_csv(cell) }.join(',')
        end
        lines.join("\n")
      end
  
      def render_tsv
        lines = [@columns.join("\t")]
        @rows.each do |row|
          lines << row.join("\t")
        end
        lines.join("\n")
      end
  
      private
  
      def escape_csv(field)
        str = field.to_s
        if str.include?(',') || str.include?('"') || str.include?("\n")
          '"' + str.gsub('"', '""') + '"'
        else
          str
        end
      end
    end
  
    module Runner
      module_function
  
      def run_all
        puts "=== THE WEB MACHINE X v#{VERSION_MAJOR}.#{VERSION_MINOR} ==="
        puts "Platform : #{WMX.target_platform} (Ruby #{RUBY_VERSION})"
  
        payload = 'NODE=WMX_X;PRECISION=4'
        frame = WMX.pack_frame(LangTag::RUBY, payload, 1)
        status, tag, flags, decoded = WMX.unpack_frame(frame)
        puts "\n[FRAME]"
        puts "Digest : 0x#{format('%08X', WMX.fnv1a_32(payload))}"
        puts "Status : #{STATUS_NAMES[status]} | Lang=#{LangTag.name_for(tag)} | Flags=#{flags}"
        puts "Match  : #{WMX.secure_mem_equal?(payload, decoded)}"
        puts WMX.hex_dump(frame)
  
        a = Fixed4.parse('250.5000')
        b = Fixed4.parse('4.0000')
        puts "\n[FIXED4]"
        puts "A=#{a} (#{a.to_cobol_pic}) | B=#{b} (#{b.to_cobol_pic})"
        puts "A+B=#{a + b} | A-B=#{a - b} | A*B=#{a * b} | A/B=#{a / b}"
  
        ring = RingBuffer.new(3)
        %w[M1 M2 M3 M4].each do |item|
          st = ring.push(item)
          puts "Ring push #{item} => #{STATUS_NAMES[st]} (size=#{ring.size}/#{ring.capacity})"
        end
        st, popped = ring.pop
        puts "Ring pop => #{STATUS_NAMES[st]} (#{popped.inspect}), remaining=#{ring.to_a.inspect}"
  
        table = RecordTable.new(%w[FILE STATUS VALUE])
        table.add_row(['webcore.pas', 'OK', Fixed4.parse('12.5000')])
        table.add_row(['coresys.cbl', 'OK', Fixed4.parse('99.0000')])
        puts "\n[TABLE]"
        puts table.render_ascii
        puts table.render_csv
      end
    end
  end
  
WMX::Runner.run_all if __FILE__ == $PROGRAM_NAME
