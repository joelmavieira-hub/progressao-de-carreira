/**
 * Safe sheet adapter. Store SUPABASE_URL and SUPABASE_SYNC_KEY in Script
 * Properties; never place credentials in this file. This file was not executed.
 */
var CAREER_REQUIRED_HEADERS = ["nome_colaborador", "posicao", "squad", "jornada", "competencia", "meta_alcancada", "senioridade_informada"];
var CAREER_VALID_SQUADS = ["Lobo", "Águia", "Sharks", "Serpente", "Gorila", "Urso", "Saiu"];
var CAREER_VALID_JOURNEYS = ["Ativo", "Inativo", "Desligado", "Saiu"];

function careerFold_(value) {
  return String(value == null ? "" : value).normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().replace(/\s+/g, " ").toLowerCase();
}

function careerCanonical_(value, domain) {
  var key = careerFold_(value);
  for (var i = 0; i < domain.length; i += 1) if (careerFold_(domain[i]) === key) return domain[i];
  return null;
}

function classifyCareerRows_(rows, existingByName) {
  return rows.map(function (row) {
    var issues = [];
    var name = String(row.nome_colaborador || "").trim().replace(/\s+/g, " ");
    var squad = careerCanonical_(row.squad, CAREER_VALID_SQUADS);
    var journey = careerCanonical_(row.jornada, CAREER_VALID_JOURNEYS);
    if (!name) issues.push(careerIssue_(row.__row, null, "nome_colaborador", row.nome_colaborador, "erro de linha", "linha ignorada", "Nome do colaborador vazio."));
    if (!squad) issues.push(careerIssue_(row.__row, name, "squad", row.squad, "erro de linha", "linha ignorada", "Squad inválido."));
    if (!String(row.jornada || "").trim()) {
      var previous = existingByName[careerFold_(name)];
      var preserved = previous && careerCanonical_(previous.jornada_atual, CAREER_VALID_JOURNEYS);
      if (preserved) {
        journey = preserved;
        issues.push(careerIssue_(row.__row, name, "jornada", "", "aviso", "jornada anterior preservada", "Jornada vazia; valor existente mantido."));
      } else issues.push(careerIssue_(row.__row, name, "jornada", "", "erro de linha", "linha ignorada", previous ? "Perfil existente sem jornada preservável." : "Jornada vazia para colaborador novo."));
    } else if (!journey) issues.push(careerIssue_(row.__row, name, "jornada", row.jornada, "erro de linha", "linha ignorada", "Jornada inválida."));
    var invalid = issues.some(function (issue) { return issue.classificacao === "erro de linha"; });
    return { classificacao: invalid ? "inválida" : issues.length ? "válida com aviso" : "válida", dados: invalid ? null : Object.assign({}, row, { nome_colaborador: name, squad: squad, jornada: journey }), issues: issues };
  });
}

function careerIssue_(line, name, field, value, classification, action, message) {
  return { linha: line, colaborador: name || null, campo: field, valor: value == null ? "" : String(value), classificacao: classification, acao: action, mensagem: message };
}

function syncCareerProgression() {
  var started = Date.now();
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var values = sheet.getDataRange().getDisplayValues();
  if (!values.length) throw new Error("Estrutura da aba incompatível: planilha vazia.");
  var headers = values[0].map(careerFold_);
  CAREER_REQUIRED_HEADERS.forEach(function (header) { if (headers.indexOf(header) < 0) throw new Error("Cabeçalho obrigatório ausente: " + header); });
  var rows = values.slice(1).filter(function (cells) { return cells.some(String); }).map(function (cells, index) {
    var row = { __row: index + 2 };
    headers.forEach(function (header, column) { row[header] = cells[column]; });
    return row;
  });
  if (rows.some(function (row) { return !/^\d{4}-(0[1-9]|1[0-2])-01$/.test(row.competencia); })) throw new Error("Competência global impossível de identificar.");

  var config = careerConfig_();
  var existing = careerFetch_(config, "/rest/v1/colaboradores_perfis?select=nome_colaborador,jornada_atual");
  var existingByName = {};
  existing.forEach(function (profile) { existingByName[careerFold_(profile.nome_colaborador)] = profile; });
  var classified = classifyCareerRows_(rows, existingByName);
  var accepted = classified.filter(function (item) { return item.dados; }).map(function (item) { return item.dados; });
  var profilesByName = {};
  accepted.forEach(function (row) { profilesByName[careerFold_(row.nome_colaborador)] = { nome_colaborador: row.nome_colaborador, posicao: row.posicao, squad: row.squad, jornada: row.jornada, ativo: row.jornada === "Ativo" }; });
  var profiles = Object.keys(profilesByName).map(function (key) { return profilesByName[key]; });
  var results = accepted.map(function (row) { return { nome_colaborador: row.nome_colaborador, posicao: row.posicao, squad: row.squad, competencia: row.competencia, meta_alcancada: row.meta_alcancada || "Sem presença", senioridade_informada: row.senioridade_informada || null }; });
  var rpc = accepted.length ? careerPost_(config, "/rest/v1/rpc/sincronizar_progressao_planilha", { p_perfis: profiles, p_resultados: results, p_origem: "google_sheets" }) : {};
  var issues = classified.reduce(function (all, item) { return all.concat(item.issues); }, []);
  var report = { status: issues.length ? "Sincronização concluída parcialmente." : "Sincronização concluída.", linhas_lidas: rows.length, linhas_validas: classified.filter(function (item) { return item.classificacao === "válida"; }).length, linhas_sincronizadas: accepted.length, linhas_com_aviso: classified.filter(function (item) { return item.classificacao === "válida com aviso"; }).length, linhas_ignoradas: classified.filter(function (item) { return item.classificacao === "inválida"; }).length, erros: issues.filter(function (item) { return item.classificacao === "erro de linha"; }), avisos: issues.filter(function (item) { return item.classificacao === "aviso"; }), perfis_atualizados: rpc.perfis_atualizados || 0, resultados_atualizados: (rpc.resultados_inseridos || 0) + (rpc.resultados_corrigidos || 0), promocoes_identificadas: rpc.promocoes_identificadas || 0, duracao_ms: Date.now() - started };
  console.log(JSON.stringify(report, null, 2));
  SpreadsheetApp.getUi().alert(report.status + "\n\n" + JSON.stringify(report, null, 2));
  return report;
}

function careerConfig_() {
  var properties = PropertiesService.getScriptProperties();
  var url = properties.getProperty("SUPABASE_URL");
  var key = properties.getProperty("SUPABASE_SYNC_KEY");
  if (!url || !key) throw new Error("Configuração do Supabase ausente.");
  return { url: url.replace(/\/$/, ""), key: key };
}

function careerFetch_(config, path) { return JSON.parse(UrlFetchApp.fetch(config.url + path, { method: "get", headers: { apikey: config.key, Authorization: "Bearer " + config.key }, muteHttpExceptions: false }).getContentText()); }
function careerPost_(config, path, payload) { return JSON.parse(UrlFetchApp.fetch(config.url + path, { method: "post", contentType: "application/json", payload: JSON.stringify(payload), headers: { apikey: config.key, Authorization: "Bearer " + config.key }, muteHttpExceptions: false }).getContentText()); }
