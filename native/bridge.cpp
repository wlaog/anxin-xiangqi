// SPDX-License-Identifier: GPL-3.0-or-later
// Small C ABI over the pinned, unmodified Pikafish source. No Tencent code.
#include "attacks.h"
#include "engine.h"
#include "movegen.h"
#include "position.h"
#include "uci.h"
#include <atomic>
#include <deque>
#include <filesystem>
#include <map>
#include <mutex>
#include <random>
#include <sstream>

#ifdef _WIN32
#define AX_API extern "C" __declspec(dllexport)
#else
#define AX_API extern "C" __attribute__((visibility("default")))
#endif

using namespace Stockfish;
namespace {
std::once_flag tables;
std::mutex searchMutex;
std::atomic<Engine*> activeEngine{nullptr};
thread_local std::string response;

void initialize() { std::call_once(tables, [] { Attacks::init(); Position::init(); }); }

void setOption(Engine* engine, const std::string& name, const std::string& value) {
    std::istringstream command("name " + name + " value " + value);
    engine->get_options().setoption(command);
}

std::vector<std::string> split(const char* text) {
    std::vector<std::string> result;
    std::istringstream stream(text ? text : "");
    std::string value;
    while (stream >> value) result.push_back(value);
    return result;
}

std::string quote(const std::string& text) {
    std::string result = "\"";
    for (unsigned char c : text) {
        if (c == '"' || c == '\\') { result += '\\'; result += c; }
        else if (c >= 32) result += c;
    }
    return result + "\"";
}

std::string error(const std::string& message) { return "{\"error\":" + quote(message) + "}"; }

bool restore(Position& position, std::deque<StateInfo>& states, const char* fen, const std::vector<std::string>& moves) {
    states.emplace_back();
    if (position.set(fen, &states.back())) return false;
    for (const auto& text : moves) {
        Move move = UCIEngine::to_move(position, text);
        if (move == Move::none()) return false;
        states.emplace_back();
        position.do_move(move, states.back(), nullptr);
    }
    return true;
}

std::string winner(Color color) { return color == WHITE ? "redWins" : "blackWins"; }

struct Verdict {
    std::string result = "playing";
    std::vector<std::string> legal, forbidden;
};

Verdict judge(Position& position, Key initialKey) {
    Verdict verdict;
    Value value;
    auto moves = MoveList<ALL>(position);
    if (moves.size() == 0) verdict.result = winner(~position.side_to_move());
    else if (position.rule_judge(value))
        verdict.result = value == VALUE_DRAW ? "draw" : winner(value > 0 ? position.side_to_move() : ~position.side_to_move());
    if (verdict.result != "playing") return verdict;
    for (Move move : moves) {
        StateInfo state;
        position.do_move(move, state, nullptr);
        // A positive rule score for the next player means this mover violated
        // perpetual-check/chase rules. Offer a different move before penalizing.
        // Treat this candidate as a search continuation, so the engine can
        // identify a losing check/chase cycle before the opponent completes it.
        // The initial state has no predecessor. Upstream's search-continuation
        // rule assumes the repeated state has one; use game adjudication there.
        const int rulePly = state.key == initialKey ? 0 : MAX_PLY;
        const bool forbidden = position.rule_judge(value, rulePly) && value > VALUE_DRAW;
        position.undo_move(move);
        (forbidden ? verdict.forbidden : verdict.legal).push_back(UCIEngine::move(move));
    }
    if (verdict.legal.empty()) verdict.result = winner(~position.side_to_move());
    return verdict;
}

std::string array(const std::vector<std::string>& values) {
    std::string result = "[";
    for (const auto& value : values) { if (result.size() > 1) result += ','; result += quote(value); }
    return result + "]";
}
}

AX_API const char* ax_rules(const char* fen, const char* history) {
    initialize();
    Position position;
    std::deque<StateInfo> states;
    if (!fen || !restore(position, states, fen, split(history))) response = error("Invalid position or history");
    else {
        auto verdict = judge(position, states.front().key);
        response = "{\"result\":" + quote(verdict.result) + ",\"legal\":" + array(verdict.legal)
            + ",\"forbidden\":" + array(verdict.forbidden) + "}";
    }
    return response.c_str();
}

AX_API void ax_stop() { if (auto engine = activeEngine.load()) engine->stop(); }

AX_API const char* ax_search(const char* fen, const char* history, const char* networkPath, int level, int seed) {
    initialize();
    std::lock_guard<std::mutex> lock(searchMutex);
    if (!networkPath || !std::filesystem::is_regular_file(std::filesystem::u8path(networkPath))) {
        response = error("NNUE network missing"); return response.c_str();
    }
    Position position;
    std::deque<StateInfo> states;
    const auto moves = split(history);
    if (!fen || !restore(position, states, fen, moves)) {
        response = error("Invalid position or history"); return response.c_str();
    }
    auto verdict = judge(position, states.front().key);
    if (verdict.result != "playing") { response = "{\"move\":null}"; return response.c_str(); }
    auto engine = activeEngine.load();
    if (!engine) {
        auto directory = std::filesystem::u8path(networkPath).parent_path();
        engine = new Engine(directory / "anxin_pikafish");
        setOption(engine, "NumaPolicy", "none");
        setOption(engine, "Threads", "1");
        setOption(engine, "Hash", "32");
        setOption(engine, "EvalFile", networkPath);
        activeEngine.store(engine);
    }
    level = std::max(1, std::min(5, level));
    const bool vary = level <= 3 || moves.size() < 12;
    setOption(engine, "MultiPV", vary ? "3" : "1");
    if (engine->set_position(fen, moves)) {
        response = error("Engine rejected position"); return response.c_str();
    }
    struct Candidate { std::string move; int score; int depth; };
    std::map<usize, Candidate> candidates;
    std::string bestMove;
    int depth = 0;
    usize nodes = 0;
    engine->set_on_update_no_moves([](const Engine::InfoShort&) {});
    engine->set_on_start([] {});
    engine->set_on_iter([](const Engine::InfoIter&) {});
    engine->set_on_verify_network([](std::string_view) {});
    engine->set_on_bestmove([&](std::string_view best, std::string_view) { bestMove = best; });
    engine->set_on_update_full([&](const Engine::InfoFull& info) {
        std::istringstream pv(std::string(info.pv)), score(UCIEngine::format_score(info.score));
        std::string move, kind; int value = 0;
        pv >> move; score >> kind >> value;
        if (!move.empty() && kind == "cp") candidates[info.multiPV] = {move, value, info.depth};
        depth = std::max(depth, info.depth); nodes = info.nodes;
    });
    Search::LimitsType limits;
    limits.startTime = now();
    limits.movetime = std::array<int, 5>{350, 650, 1000, 1800, 3000}[level - 1];
    limits.nodes = std::array<u64, 5>{1200, 8000, 60000, 500000, 0}[level - 1];
    limits.searchmoves = verdict.legal;
    engine->go(limits);
    engine->wait_for_search_finished();
    if (vary && !candidates.empty()) {
        const int band = std::array<int, 5>{120, 70, 25, 15, 10}[level - 1];
        int best = -1000000;
        for (const auto& [index, c] : candidates) if (c.depth == depth) best = std::max(best, c.score);
        std::vector<std::string> choices;
        for (const auto& [index, c] : candidates)
            if (c.depth == depth && c.score >= best - band
                && std::find(verdict.legal.begin(), verdict.legal.end(), c.move) != verdict.legal.end()) choices.push_back(c.move);
        if (!choices.empty()) bestMove = choices[std::mt19937(static_cast<unsigned>(seed))() % choices.size()];
    }
    // Never return an engine protocol sentinel or a stale/forbidden move.
    if (std::find(verdict.legal.begin(), verdict.legal.end(), bestMove) == verdict.legal.end()) {
        response = error("Engine returned no permitted move"); return response.c_str();
    }
    response = "{\"move\":" + quote(bestMove) + ",\"depth\":" + std::to_string(depth)
        + ",\"nodes\":" + std::to_string(nodes) + "}";
    return response.c_str();
}
