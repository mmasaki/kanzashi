p [:plugin_sample, :config, K.c]
Kh.start {|*a| p [:plugin_sample, :start, a] }
Kh.connect {|*a| p [:plugin_sample, :connect, a] }
Kh.connected {|*a| p [:plugin_sample, :connected, a] }
Kh.started {|*a| p [:plugin_sample, :started, a] }
Kh.receive_line {|*a| p [:plugin_sample, :receive_line, a] }
Kh.notice{ |*a| p [:plugin_sample, :notice, a] }
