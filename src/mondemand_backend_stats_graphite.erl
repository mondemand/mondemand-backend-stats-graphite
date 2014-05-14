-module (mondemand_backend_stats_graphite).

-behaviour (gen_server).
-behaviour (mondemand_server_backend).
-behaviour (mondemand_backend_stats_handler).

%% mondemand_server_backend callbacks
-export ([ start_link/1,
           process/1,
           stats/0,
           required_apps/0
         ]).

%% mondemand_backend_stats_handler callbacks
-export ([ header/0,
           separator/0,
           format_stat/8,
           footer/0,
           handle_response/2
         ]).

%% gen_server callbacks
-export ([ init/1,
           handle_call/3,
           handle_cast/2,
           handle_info/2,
           terminate/2,
           code_change/3
         ]).

-record (state, { sidejob,
                  stats = dict:new ()
                }).

%%====================================================================
%% mondemand_server_backend callbacks
%%====================================================================
start_link (Config) ->
  gen_server:start_link ( { local, ?MODULE }, ?MODULE, Config, []).

process (Event) ->
  mondemand_backend_connection_pool:cast (?MODULE, {process, Event}).

stats () ->
  gen_server:call (?MODULE, {stats}).

required_apps () ->
  [ sidejob ].

%%====================================================================
%% gen_server callbacks
%%====================================================================
init (Config) ->
  Limit = proplists:get_value (limit, Config, 10),
  Number = proplists:get_value (number, Config, undefined),

  { ok, Proc } =
    mondemand_backend_connection_pool:init ([?MODULE, Limit, Number]),
  { ok, #state { sidejob = Proc } }.

handle_call ({stats}, _From, State) ->
  Stats = mondemand_backend_connection_pool:stats (?MODULE),
  { reply, Stats, State };
handle_call (Request, From, State) ->
  error_logger:warning_msg ("~p : Unrecognized call ~p from ~p~n",
                            [?MODULE, Request, From]),
  { reply, ok, State }.

handle_cast (Request, State) ->
  error_logger:warning_msg ("~p : Unrecognized cast ~p~n",[?MODULE, Request]),
  { noreply, State }.

handle_info (Request, State) ->
  error_logger:warning_msg ("~p : Unrecognized info ~p~n",[?MODULE, Request]),
  {noreply, State}.

terminate (_Reason, #state { }) ->
  ok.

code_change (_OldVsn, State, _Extra) ->
  {ok, State}.

%%====================================================================
%% mondemand_backend_stats_handler callbacks
%%====================================================================
header () -> "".

separator () -> "\n".

format_stat (Prefix, ProgId, Host,
             MetricType, MetricName, MetricValue, Timestamp, Context) ->
  ActualPrefix = case Prefix of undefined -> ""; _ -> [ Prefix, "." ] end,
  [ ActualPrefix,
    ProgId, ".",
    MetricType, ".",
    MetricName, ".",
    Host,
    case Context of
      [] -> "";
      L -> [".", mondemand_server_util:join ([[K,"=",V] || {K, V} <- L ], ".")]
    end,
    io_lib:fwrite (" ~b ~b", [MetricValue, Timestamp])
  ].

footer () -> "\n".

handle_response (Response, _) ->
  error_logger:info_msg ("~p : got unexpected response ~p",[?MODULE, Response]),
  {0,undefined}.
