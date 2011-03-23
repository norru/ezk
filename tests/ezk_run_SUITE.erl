%%%-------------------------------------------------------------------
%%% @author Marco <marco@gauss.gi.net>
%%% @copyright (C) 2011, Marco
%%% @doc
%%%
%%% @end
%%% Created : 23 Mar 2011 by Marco <marco@gauss.gi.net>
%%%-------------------------------------------------------------------
-module(ezk_run_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-define(RUN_ROUNDS,10).
-define(DATALENGTH, 10).

suite() ->
    [{timetrap,{seconds,300}}].

init_per_suite(Config) ->
    application:start(ezk),
    application:start(sasl),
    Config.

end_per_suite(_Config) ->
    application:stop(ezk),
    application:stop(sasl),

    ok.

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, _Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

groups() ->
    RunCases = [{run100,100},
    	      {run200,200},
    	      {run500,500},
    	      {run700,700},
    	      {run900,900}
    	      ],
    [{Name, [parallel], [run_test || _Id <- lists:seq(1,Para)]} 
	    || {Name, Para} <- RunCases ]. 

all() -> 
    [{group, N} || {N, _, _} <- groups()].

run_test(Config) ->
    ok = run_test(Config, ?RUN_ROUNDS).
run_test(_Config, Cycles) ->
    List  = sequenzed_create("/run_multi",Cycles,[]),
    ok    = test_data(List),
    List2 = change_data(List,[]),
    ok    = test_data(List2),    
    ok    = set_watch_and_test( List2),
    spawn(fun() -> change_data(List2, []) end),
    ok    = wait_watches(List2),
    ok    = sequenzed_delete(List2).
    
wait_watches([]) ->
    ok;
wait_watches([{Path, _Data} | Tail]) ->
    receive
       {{datawatch, Path}, _Left} ->
	    wait_watches(Tail)
    end.
    
sequenzed_delete([]) ->
    ok;
sequenzed_delete([{Path,_Data} | Tail]) ->
    {ok, Path} = ezk_connection:delete(Path),
    sequenzed_delete(Tail).

set_watch_and_test([])->
    ok;
set_watch_and_test([{Path,Data} | Tail]) ->
    Self = self(),
    {ok, {Data, _I}} = ezk_connection:get(Path, Self, {datawatch, Path}),
    set_watch_and_test(Tail).

change_data([], NewList) ->
    NewList;
change_data([{Path, _Data} | Tail], NewList) ->
    NewData = stringmaker(?DATALENGTH),
    {ok, _I} = ezk_connection:set(Path, NewData),
    change_data(Tail, [{Path, NewData} | NewList]).

test_data([]) ->
    ok;
test_data([{Path, Data} | Tail]) ->
    {ok, {Data, _I}} = ezk_connection:get(Path),
    test_data(Tail).

sequenzed_create(_Path, 0, List) ->
    List;
sequenzed_create(Path, CyclesLeft, List) ->
    Data = stringmaker(?DATALENGTH),
    {ok, Name} = ezk_connection:create(Path, Data, s),
    sequenzed_create(Path, CyclesLeft-1, [{Name, Data} | List]).

stringmaker(N) ->
    lists:seq(1,N).
    
