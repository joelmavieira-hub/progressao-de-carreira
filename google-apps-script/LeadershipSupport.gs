/**
 * Companion patch for Apps Script 2026-09-02.1.
 *
 * This file does not touch the spreadsheet or the incremental cache. Add it as
 * a separate .gs file and call normalizarResultadoComLideranca_ immediately
 * before the existing META_INVALIDA classification and payload construction.
 * The returned position and goal must be sent together to the RPC.
 */
var POSICOES_PROGRESSAO_COM_LIDERANCA_ = [
  "SDR",
  "Closer",
  "Liderança de SDRs",
  "Liderança de Closers"
];

function dobrarTextoProgressao_(value) {
  return String(value == null ? "" : value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .replace(/\s+/g, " ")
    .toLowerCase();
}

function canonicalizarPosicaoProgressao_(value) {
  var folded = dobrarTextoProgressao_(value);
  for (var index = 0; index < POSICOES_PROGRESSAO_COM_LIDERANCA_.length; index += 1) {
    if (dobrarTextoProgressao_(POSICOES_PROGRESSAO_COM_LIDERANCA_[index]) === folded) {
      return POSICOES_PROGRESSAO_COM_LIDERANCA_[index];
    }
  }
  return null;
}

function normalizarResultadoComLideranca_(posicaoOriginal, metaOriginal) {
  var position = canonicalizarPosicaoProgressao_(posicaoOriginal);
  if (!position) {
    return { valido: false, codigo: "FUNCAO_INVALIDA", posicao: null, meta: null };
  }

  var foldedGoal = dobrarTextoProgressao_(metaOriginal);
  var suffix = foldedGoal.match(/^meta ([123]) \((lideranca de sdrs|lideranca de closers)\)$/);
  if (suffix) {
    var expectedPosition = suffix[2] === "lideranca de sdrs"
      ? "Liderança de SDRs"
      : "Liderança de Closers";
    if (position !== expectedPosition) {
      return {
        valido: false,
        codigo: "META_POSICAO_INCONSISTENTE",
        posicao: position,
        meta: null
      };
    }
    return { valido: true, codigo: null, posicao: position, meta: "Meta " + suffix[1] };
  }

  var goals = {
    "": "Sem presença",
    "sem presenca": "Sem presença",
    "ausente": "Sem presença",
    "meta nao definida": "Sem presença",
    "meta 1": "Meta 1",
    "meta 2": "Meta 2",
    "meta 3": "Meta 3",
    "nenhuma meta": "Nenhuma meta",
    "sem meta": "Nenhuma meta",
    "sem registro": "Nenhuma meta"
  };
  var goal = Object.prototype.hasOwnProperty.call(goals, foldedGoal)
    ? goals[foldedGoal]
    : null;
  return {
    valido: goal !== null,
    codigo: goal === null ? "META_INVALIDA" : null,
    posicao: position,
    meta: goal
  };
}

function testarSuporteLideranca_() {
  var cases = [
    ["Liderança de SDRs", "Meta 3 (Liderança de SDRs)", true, "Meta 3"],
    ["Liderança de Closers", "Meta 2 (Liderança de Closers)", true, "Meta 2"],
    ["SDR", "Meta 3 (Liderança de SDRs)", false, null],
    ["Closer", "Meta 3", true, "Meta 3"]
  ];
  cases.forEach(function (item) {
    var actual = normalizarResultadoComLideranca_(item[0], item[1]);
    if (actual.valido !== item[2] || actual.meta !== item[3]) {
      throw new Error("Falha no contrato de liderança: " + JSON.stringify(item));
    }
  });
  return { sucesso: true, casos: cases.length };
}
