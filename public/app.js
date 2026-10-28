const copy = {
  et: {
    title: "Vaata ettevõtet",
    lead: "Vali riik ja sisesta registrikood. Koodi kuju sõltub valitud riigist. Avalik register ei pruugi anda e-posti, telefoni ega esindajaid.",
    countries: { BG: "Bulgaaria", CZ: "Tšehhi", EE: "Eesti", FI: "Soome", FR: "Prantsusmaa", LT: "Leedu", LV: "Läti", NO: "Norra", PL: "Poola", SK: "Slovakkia" },
    country: "Riigikood",
    registry: "Registrikood",
    search: "Otsi",
    searching: "Otsin...",
    sampleLabel: "Näidis",
    org: "Eesti Interneti Sihtasutus",
    product: "Ettevõtte päring",
    pageTitle: "Ettevõtte päring",
    email: "E-post",
    phone: "Telefon",
    address: "Aadress",
    registered: "Registreeritud",
    deleted: "Kustutatud",
    status: "Staatus",
    representatives: "Esindajad",
    noRepresentatives: "Esindajaid ei ole.",
    personalCode: "Isikukood",
    validFrom: "Kehtiv alates",
    active: "Aktiivne",
    inactive: "Mitteaktiivne",
    nameMissing: "Nimi puudub",
    apiResponse: "API vastus",
    loading: "Päring käib.",
    apiDown: "API ei vastanud",
    requestFailed: "Päring ebaõnnestus",
    language: "Keel"
  },
  en: {
    title: "Look up a company",
    lead: "Choose a country and enter a registry code. The code format depends on the selected country. A public register may not provide email, phone or representatives.",
    countries: { BG: "Bulgaria", CZ: "Czechia", EE: "Estonia", FI: "Finland", FR: "France", LT: "Lithuania", LV: "Latvia", NO: "Norway", PL: "Poland", SK: "Slovakia" },
    country: "Country code",
    registry: "Registry code",
    search: "Search",
    searching: "Searching...",
    sampleLabel: "Example",
    org: "Estonian Internet Foundation",
    product: "Company lookup",
    pageTitle: "Company lookup",
    email: "Email",
    phone: "Phone",
    address: "Address",
    registered: "Registered",
    deleted: "Deleted",
    status: "Status",
    representatives: "Representatives",
    noRepresentatives: "No representatives.",
    personalCode: "Personal code",
    validFrom: "Valid from",
    active: "Active",
    inactive: "Inactive",
    nameMissing: "Name missing",
    apiResponse: "API response",
    loading: "Request in progress.",
    apiDown: "The API did not respond",
    requestFailed: "The request failed",
    language: "Language"
  }
};

const statuses = {
  R: { et: "Registrisse kantud", en: "Entered in the register" },
  L: { et: "Likvideerimisel", en: "In liquidation" },
  N: { et: "Pankrotis", en: "In bankruptcy" },
  K: { et: "Kustutatud", en: "Deleted" },
  "0": { et: "Registreerimata", en: "Unregistered" },
  "1": { et: "Registrisse kantud", en: "Entered in the register" },
  "2": { et: "Registrist kustutatud", en: "Removed from the register" },
  "3": { et: "Registreerimata alustav ettevõte", en: "Unregistered start-up" },
  "4": { et: "Tegevus lõppenud", en: "Ceased" },
  "5": { et: "Ärikood kehtetu", en: "Business ID invalidated" },
  REORG: { et: "Reorganiseeritud", en: "Reorganised" },
  RS: { et: "Restruktureerimisel", en: "Under restructuring" },
  LT1: { et: "Reorganiseeritakse", en: "Under reorganisation" },
  LT2: { et: "Osaleb reorganiseerimises", en: "Participating in reorganisation" },
  LT3: { et: "Ümberkujundamisel", en: "Under conversion" },
  LT4: { et: "Restruktureerimisel", en: "Under restructuring" },
  LT5: { et: "Pankrotimenetluses", en: "In bankruptcy proceedings" },
  LT6: { et: "Pankrotis", en: "Bankrupt" },
  LT7: { et: "Likvideerimisel", en: "In liquidation" },
  LT8: { et: "Osaleb eraldumises", en: "Participating in a division" },
  LT9: { et: "Likvideerimist algatatakse", en: "Liquidation being initiated" },
  LT10: { et: "Registrist kustutatud", en: "Removed from the register" },
  LT11: { et: "Likvideeritud", en: "Liquidated" },
  LT12: { et: "Ümber registreerimata", en: "Not reregistered" },
  LT13: { et: "Pankrotimenetluses", en: "In bankruptcy proceedings" },
  LT16: { et: "Asutab ühinemisega Euroopa äriühingut", en: "Forming a European company by merger" },
  LT17: { et: "Asutab valitseva Euroopa äriühingut", en: "Forming a European company by holding" },
  LT18: { et: "Euroopa äriühing viib asukohta üle", en: "European company transferring its office" },
  LT19: { et: "Asutab ühinemisega Euroopa ühistut", en: "Forming a European cooperative by merger" },
  LT20: { et: "Euroopa ühistu viib asukohta üle", en: "European cooperative transferring its office" },
  LT21: { et: "Piiriülene ühinemine", en: "Cross-border merger" },
  LT22: { et: "Osaleb piiriüleses ühinemises", en: "Participating in a cross-border merger" },
  LT23: { et: "Piiriülene ühinemine", en: "Cross-border merger" },
  LT24: { et: "Osaleb piiriüleses ühinemises", en: "Participating in a cross-border merger" },
  LT25: { et: "Viib asukohta üle", en: "Transferring the registered office" },
  LT26: { et: "Likvideerimisel pankroti tõttu", en: "In liquidation due to bankruptcy" },
  LT27: { et: "Piiriülene ühinemine", en: "Cross-border merger" },
  LT28: { et: "Osaleb piiriüleses ühinemises", en: "Participating in a cross-border merger" },
  LT29: { et: "Piiriülene ümberkujundamine", en: "Cross-border conversion" },
  LT30: { et: "Piiriülene jagunemine", en: "Cross-border division" },
  LT31: { et: "Asutab valitsevat Euroopa äriühingut", en: "Forming a controlling European company" },
  LT32: { et: "Viib asukoha teise riiki", en: "Transferring the registered office to another country" }
};

const roles = {
  "Management board member": "Juhatuse liige",
  "Chair of the management board": "Juhatuse esimees",
  "Vice-chair of the management board": "Juhatuse aseesimees",
  "Supervisory board member": "Nõukogu liige",
  "Chair of the supervisory board": "Nõukogu esimees",
  "Vice-chair of the supervisory board": "Nõukogu aseesimees",
  "Shareholder": "Osanik",
  "Stockholder": "Aktsionär",
  "Person authorised to represent the agency": "Asutuse esindusõiguslik isik",
  "Superior agency": "Kõrgemalseisev asutus",
  "Liquidator": "Likvideerija",
  "Trustee in bankruptcy": "Pankrotihaldur",
  "Procurator": "Prokurist",
  "Founder": "Asutaja",
  "Member of the audit committee": "Revisjonikomisjoni liige",
  "Auditor": "Audiitor",
  "Deputy board member": "Nõukogu asendusliige",
  "Accountant": "Raamatupidaja",
  "Owner": "Omanik",
  "Co-owner": "Kaasomanik",
  "Member": "Liige",
  "Representative manager": "Esindusõiguslik juht",
  "Administrator": "Administraator",
  "Authorised representative": "Volitatud esindaja",
  "President": "President",
  "Manager": "Juhataja",
  "Estate trustee": "Pärandvara hooldaja",
  "Managing director": "Tegevdirektor",
  "Other": "Muu",
  "Representative of the liquidator": "Likvideerija esindaja"
};

const apiErrors = {
  "Only Bulgarian, Czech, Estonian, Finnish, French, Latvian, Lithuanian, Norwegian, Polish and Slovak companies are supported": "Toetatud on Bulgaaria, Eesti, Leedu, Läti, Norra, Poola, Prantsusmaa, Slovakkia, Soome ja Tšehhi ettevõtted",
  "The Slovak registry code must be an 8-digit number": "Slovakkia registrikood peab olema 8-kohaline number",
  "The Czech registry code must be an 8-digit number": "Tšehhi registrikood peab olema 8-kohaline number",
  "The Bulgarian registry code must be a 9-digit number": "Bulgaaria registrikood peab olema 9-kohaline number",
  "The French registry code must be a 9-digit number": "Prantsuse registrikood peab olema 9-kohaline number",
  "The Norwegian registry code must be a 9-digit number": "Norra registrikood peab olema 9-kohaline number",
  "The Polish registry code must be a 10-digit number": "Poola registrikood peab olema 10-kohaline number",
  "The registry code must be an 8-digit number": "Ettevõtte kood peab olema 8-kohaline number",
  "The Lithuanian registry code must be a 9-digit number": "Leedu registrikood peab olema 9-kohaline number",
  "The Latvian registry code must be an 11-digit number": "Läti registrikood peab olema 11-kohaline number",
  "The Finnish registry code must look like 1234567-8": "Soome registrikood peab olema kujul 1234567-8",
  "Company not found": "Ettevõtet ei leitud",
  "The business register request failed": "Äriregistri päring ebaõnnestus",
  "Address not found": "Aadressi ei leitud",
  "The request failed": "Päring ebaõnnestus"
};

const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const samples = {
  BG: "130007884",
  CZ: "00177041",
  EE: "12417834",
  FI: "0112038-9",
  FR: "552081317",
  LT: "121215434",
  LV: "40003032949",
  NO: "923609016",
  PL: "0000006865",
  SK: "35763469"
};

const form = document.querySelector("#lookup");
const countryInput = document.querySelector("#country");
const codeInput = document.querySelector("#code");
const result = document.querySelector("#result");
const submitButton = document.querySelector("#submit");
const langSwitch = document.querySelector("#lang-switch");
const sampleButton = document.querySelector("#sample");

let lang = initialLang();
let lastView = null;

countryInput.addEventListener("change", applySample);

sampleButton.addEventListener("click", function () {
  const code = samples[countryInput.value];
  if (!code) return;
  codeInput.value = code;
  codeInput.focus();
});

form.addEventListener("submit", function (event) {
  event.preventDefault();
  lookup(countryInput.value.trim().toUpperCase(), codeInput.value.trim());
});

langSwitch.addEventListener("click", function (event) {
  const next = event.target.getAttribute("data-set-lang");
  if (next !== "et" && next !== "en") return;
  if (next === lang) return;
  lang = next;
  localStorage.setItem("company-api-lang", lang);
  const url = new URL(location.href);
  url.searchParams.set("lang", lang);
  history.replaceState(null, "", url);
  applyLanguage();
  if (lastView) renderLast();
});

applyLanguage();

function initialLang() {
  const query = new URLSearchParams(location.search).get("lang");
  if (query === "en" || query === "et") return query;
  const saved = localStorage.getItem("company-api-lang");
  if (saved === "en" || saved === "et") return saved;
  return "et";
}

function t(key) {
  return copy[lang][key];
}

function applyLanguage() {
  document.documentElement.lang = lang;
  document.title = t("pageTitle");
  document.querySelector(".brand img").alt = t("org");
  langSwitch.setAttribute("aria-label", t("language"));
  document.querySelectorAll("[data-i18n]").forEach(function (node) {
    if (node === submitButton && submitButton.disabled) {
      node.textContent = t("searching");
      return;
    }
    node.textContent = t(node.getAttribute("data-i18n"));
  });
  langSwitch.querySelectorAll("button").forEach(function (button) {
    button.setAttribute("aria-pressed", String(button.getAttribute("data-set-lang") === lang));
  });
  countryInput.querySelectorAll("option").forEach(function (option) {
    option.textContent = option.value + " " + copy[lang].countries[option.value];
  });
  applySample();
}

function applySample() {
  const code = samples[countryInput.value] || samples.EE;
  sampleButton.textContent = t("sampleLabel") + " " + code;
  codeInput.placeholder = code;
}

async function lookup(country, code) {
  const path = "/companies/" + encodeURIComponent(country) + "/" + encodeURIComponent(code);
  submitButton.disabled = true;
  submitButton.textContent = t("searching");
  result.replaceChildren(notice(t("loading")));

  try {
    const response = await fetch(path);
    const data = await response.json();
    if (!response.ok) {
      lastView = { type: "error", path: path, status: response.status, data: data };
      renderLast();
      return;
    }
    lastView = { type: "company", path: path, status: response.status, data: data };
    renderLast();
  } catch (error) {
    lastView = { type: "error", path: path, status: 0, data: { error: String(error) }, client: "apiDown" };
    renderLast();
  } finally {
    submitButton.disabled = false;
    submitButton.textContent = t("search");
  }
}

function renderLast() {
  if (!lastView) return;
  if (lastView.type === "company") {
    showCompany(lastView.data, lastView.path, lastView.status);
    return;
  }
  const message = lastView.client ? t(lastView.client) : translateError(lastView.data.error);
  showError(message, lastView.path, lastView.status, lastView.data);
}

function translateError(message) {
  if (lang === "et" && apiErrors[message]) return apiErrors[message];
  return message || t("requestFailed");
}

function showError(message, path, status, data) {
  const box = notice(message);
  box.classList.add("error");
  box.append(requestLine(path, status));
  result.replaceChildren(box, rawBlock(data));
}

function showCompany(company, path, status) {
  const card = el("article", "company");
  const head = el("div", "company-head");
  const title = el("div");
  title.append(el("h2", null, company.name || t("nameMissing")));
  title.append(el("p", "registry", company.country_code + " · " + company.registry_code));
  head.append(title, pill(company));
  card.append(head);

  const facts = el("div", "facts");
  facts.append(fact(t("email"), mail(company.email)));
  facts.append(fact(t("phone"), telephone(company.phone)));
  facts.append(fact(t("address"), textOrEmpty(company.address)));
  facts.append(fact(t("status"), statusName(company)));
  facts.append(fact(t("registered"), formatDate(company.registered_on)));
  if (company.deleted_on) facts.append(fact(t("deleted"), formatDate(company.deleted_on)));
  card.append(facts, people(company.representatives), requestLine(path, status));
  result.replaceChildren(card, rawBlock(company));
}

function statusName(company) {
  const code = company.status && company.status.code;
  if (statuses[code]) return statuses[code][lang];
  return company.status && company.status.name ? company.status.name : "—";
}

function people(list) {
  const block = el("div", "people");
  block.append(el("h3", null, t("representatives")));
  if (!list || list.length === 0) {
    block.append(el("p", "registry", t("noRepresentatives")));
    return block;
  }
  const rows = el("div", "person-list");
  list.forEach(function (person) {
    const row = el("div", "person");
    const name = el("div");
    name.append(el("strong", null, person.name || "—"));
    name.append(el("small", null, roleName(person.role)));
    row.append(
      name,
      labeled(t("personalCode"), person.personal_code),
      labeled(t("validFrom"), formatDate(person.valid_from))
    );
    rows.append(row);
  });
  block.append(rows);
  return block;
}

function roleName(role) {
  if (!role) return "";
  if (lang === "et" && roles[role]) return roles[role];
  return role;
}

function labeled(label, value) {
  const node = el("div");
  node.append(el("small", null, label));
  node.append(el("strong", null, textOrEmpty(value)));
  return node;
}

function fact(label, value) {
  const node = el("div", "fact");
  node.append(el("span", null, label));
  if (value instanceof Node) node.append(value);
  else node.append(document.createTextNode(textOrEmpty(value)));
  return node;
}

function mail(address) {
  if (!address) return document.createTextNode("—");
  const link = document.createElement("a");
  link.href = "mailto:" + address;
  link.textContent = address;
  return link;
}

function telephone(number) {
  if (!number) return document.createTextNode("—");
  if (number.includes(",")) return document.createTextNode(number);
  const link = document.createElement("a");
  link.href = "tel:" + number.replace(/[^\d+]/g, "");
  link.textContent = number;
  return link;
}

function pill(company) {
  return el("span", company.active ? "pill ok" : "pill wait", company.active ? t("active") : t("inactive"));
}

function requestLine(path, status) {
  const text = status ? "GET " + path + "  ·  " + status : "GET " + path;
  return el("p", "request-line", text);
}

function rawBlock(data) {
  const details = el("details", "raw");
  details.open = true;
  details.append(el("summary", null, t("apiResponse")));
  details.append(el("pre", null, JSON.stringify(data, null, 2)));
  return details;
}

function notice(message) {
  return el("div", "notice", message);
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

function textOrEmpty(value) {
  return value ? String(value) : "—";
}

function formatDate(value) {
  const match = String(value || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return textOrEmpty(value);
  if (lang === "en") return Number(match[3]) + " " + months[Number(match[2]) - 1] + " " + match[1];
  return match[3] + "." + match[2] + "." + match[1];
}
