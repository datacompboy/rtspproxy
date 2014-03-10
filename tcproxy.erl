-module(tcproxy).
-export([run_proxy/0, start_rtsp_proxy/3, start_onvif_proxy/4]).

run_proxy() ->
    tcp_server:start_raw_server(11554, fun(S) -> ?MODULE:start_rtsp_proxy("172.28.1.90", 554, S) end, 100, 0),
    tcp_server:start_raw_server(1181, fun(S) -> ?MODULE:start_rtsp_proxy("172.28.1.90", 80, S) end, 100, 0),
    tcp_server:start_raw_server(1180, fun(S) -> ?MODULE:start_onvif_proxy("172.28.1.90", 80, [{<<"172.28.1.90:554">>, <<"127.0.0.1:11554">>},{<<"172.28.1.90:80">>, <<"127.0.0.1:1180">>}], S) end, 100, 0),
    ok.

start_onvif_proxy(Host, Port, Substr, Socket) ->
    {ok, SrvSocket} = gen_tcp:connect(Host, Port, [binary, {packet, 0}, {active, true}, {buffer, 1024*1024}, {delay_send, false}, {deliver, term}, {keepalive, true}, {mode, binary}, {nodelay, true}]),
    io:format("New ONVIF connection~n", []),
    run_replace_proxy(Socket, SrvSocket, Substr).

run_replace_proxy(S1, S2, Substr) ->
  receive
    {tcp_closed, _} -> ok;
    {tcp_error, _, _Reason} -> ok;
    {tcp,S1,Data} ->
        gen_tcp:send(S2, Data),
        run_replace_proxy(S1, S2, Substr);
    {tcp,S2,Data} ->
        NewData = lists:foldl(fun({Orig,Repl},DataIn)->binary:replace(DataIn, Orig, Repl)end, Data, Substr),
        gen_tcp:send(S1, NewData), 
        run_replace_proxy(S1, S2, Substr);
    _Unk -> io:format("Unknown message ~p~n", [_Unk]), run_proxy(S1, S2)
  end.

start_rtsp_proxy(Host, Port, Socket) ->
    {ok, SrvSocket} = gen_tcp:connect(Host, Port, [binary, {packet, 0}, {active, true}, {buffer, 1024*1024}, {delay_send, false}, {deliver, term}, {keepalive, true}, {mode, binary}, {nodelay, true}]),
    io:format("New RTSP connection~n", []),
    run_proxy(Socket, SrvSocket).

run_proxy(S1, S2) ->
  receive
    {tcp_closed, _} -> ok;
    {tcp_error, _, _Reason} -> ok;
    {tcp,S1,Data} ->
        gen_tcp:send(S2, Data),
        {message_queue_len, MQL} = erlang:process_info(self(), message_queue_len),
        if MQL > 100 -> 
                io:format("Message queue overloaded ~p!~n", [MQL]),
                run_proxy2(S1, S2);
           true -> run_proxy(S1, S2)
        end;
    {tcp,S2,Data} ->
        gen_tcp:send(S1, Data), 
        {message_queue_len, MQL} = erlang:process_info(self(), message_queue_len),
        if MQL > 100 -> 
                io:format("Message queue overloaded ~p!~n", [MQL]),
                run_proxy2(S1, S2);
           true -> run_proxy(S1, S2)
        end;
    _Unk -> io:format("Unknown message ~p~n", [_Unk]), run_proxy(S1, S2)
  end.

run_proxy2(S1, S2) ->
  receive
    {tcp_closed, _} -> ok;
    {tcp_error, _, _Reason} -> ok;
    {tcp,S1,Data} ->
        gen_tcp:send(S2, Data),
        {message_queue_len, MQL} = erlang:process_info(self(), message_queue_len),
        if MQL < 100 -> 
                io:format("Message queue fine!~n"),
                run_proxy(S1, S2);
           true -> run_proxy2(S1, S2)
        end;
    {tcp,S2,Data} ->
        gen_tcp:send(S1, Data), 
        {message_queue_len, MQL} = erlang:process_info(self(), message_queue_len),
        if MQL < 100 -> 
                io:format("Message queue fine!~n"),
                run_proxy(S1, S2);
           true -> run_proxy2(S1, S2)
        end;
    _Unk -> io:format("Unknown message ~p~n", [_Unk]), run_proxy(S1, S2)
  end.
