-module (mondemand_backend_stats_graphite).

-behaviour (supervisor).
-behaviour (mondemand_server_backend).
-behaviour (mondemand_backend_stats_handler).

%% mondemand_server_backend callbacks
-export ([ start_link/1,
           process/1,
           required_apps/0,
           type/0
         ]).

%% mondemand_backend_stats_handler callbacks
-export ([ header/0,
           separator/0,
           format_stat/10,
           footer/0,
           handle_response/2
         ]).

%% supervisor callbacks
-export ([init/1]).

%%====================================================================
%% mondemand_server_backend callbacks
%%====================================================================
start_link (Config) ->
  supervisor:start_link ( { local, ?MODULE }, ?MODULE, [Config]).

process (Event) ->
 mondemand_backend_worker_pool_sup:process
    (mondemand_backend_stats_graphite_worker_pool, Event).

required_apps () ->
  [ ].

type () ->
  supervisor.

%%====================================================================
%% supervisor callbacks
%%====================================================================
init ([Config]) ->
  % default to one process per scheduler
  Number = proplists:get_value (number, Config, erlang:system_info(schedulers)),

  { ok,
    {
      {one_for_one, 10, 10},
      [
        { mondemand_backend_stats_graphite_worker_pool,
          { mondemand_backend_worker_pool_sup, start_link,
            [ mondemand_backend_stats_graphite_worker_pool,
              mondemand_backend_connection,
              Number,
              ?MODULE ]
          },
          permanent,
          2000,
          supervisor,
          [ ]
        }
      ]
    }
  }.

%%====================================================================
%% mondemand_backend_stats_handler callbacks
%%====================================================================
header () -> "".

separator () -> "\n".

format_stat (_Num, _Total, Prefix, ProgId, Host,
             MetricType, MetricName, MetricValue, Timestamp, Context) ->
  ActualPrefix = case Prefix of undefined -> ""; _ -> [ Prefix, "." ] end,
  { ok,
    [ ActualPrefix,
      ProgId, ".",
      MetricName, ".",
      normalize(Host),
      case Context of
        [] -> "";
        L -> [".", mondemand_server_util:join ([[K,"=",V] || {K, V} <- L ], ".")]
      end,
      ".type=", atom_to_list (MetricType),
      io_lib:fwrite (" ~b ~b", [MetricValue, Timestamp])
    ],
    1,
    0
  }.

footer () -> "\n".

handle_response (Response, _) ->
  error_logger:info_msg ("~p : got unexpected response ~p",[?MODULE, Response]),
  {0,undefined}.

% graphite seems to use . as a separator, so make sure to get rid of them
normalize (V) ->
  re:replace(V,"\\.","_", [{return, list}]).
