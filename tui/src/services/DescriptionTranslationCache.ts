import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'
import crypto from 'node:crypto'

const CACHE_FILE = path.join(os.homedir(), '.skills-manager', 'cache', 'description-translations.json')
const TRANSLATOR_VERSION = 'description-v2'

interface TranslationEntry {
  skillID: string
  sourceTextHash: string
  sourceLocale?: string
  targetLocale: string
  translatedText: string
  translatorVersion: string
  createdAt: string
  lastAccessedAt: string
}

interface TranslationCacheFile {
  entries: Record<string, TranslationEntry>
}

const EXPLICIT_LOCALE_KEYS = [
  'description_locale',
  'descriptionLocale',
  'description-language',
  'description_language',
  'locale',
  'language',
  'lang',
]

const LOCALE_ALIASES: Record<string, string> = {
  english: 'en',
  英文: 'en',
  英语: 'en',
  chinese: 'zh-Hans',
  中文: 'zh-Hans',
  简体: 'zh-Hans',
  简体中文: 'zh-Hans',
  'simplified-chinese': 'zh-Hans',
  'simplified chinese': 'zh-Hans',
  'zh-cn': 'zh-Hans',
  'zh-sg': 'zh-Hans',
  'zh-my': 'zh-Hans',
  繁體: 'zh-Hant',
  繁体: 'zh-Hant',
  繁體中文: 'zh-Hant',
  繁体中文: 'zh-Hant',
  'traditional-chinese': 'zh-Hant',
  'traditional chinese': 'zh-Hant',
  'zh-tw': 'zh-Hant',
  'zh-hk': 'zh-Hant',
  'zh-mo': 'zh-Hant',
  japanese: 'ja',
  日本語: 'ja',
  日语: 'ja',
  korean: 'ko',
  한국어: 'ko',
  韩语: 'ko',
  french: 'fr',
  français: 'fr',
  german: 'de',
  deutsch: 'de',
  spanish: 'es',
  español: 'es',
}

const SIMPLIFIED_CHINESE_CHARS = new Set([...('这为会来过对经个们现发后实还样进开关问题学国时说没给让从将门间与无见电车长马风东话处声点买卖体网线云台页机级尽变边于优简译广气书区师数应论认设请识读写')])
const TRADITIONAL_CHINESE_CHARS = new Set([...('這為會來過對經個們現發後實還樣進開關問題學國時說沒給讓從將門間與無見電車長馬風東話處聲點買賣體網線雲臺頁機級盡變邊於優簡譯廣氣書區師數應論認設請識讀寫')])

function readCacheFile(): TranslationCacheFile | null {
  try {
    return JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8')) as TranslationCacheFile
  } catch {
    return null
  }
}

export function getCurrentDescriptionLocale(): string {
  const stateFile = path.join(os.homedir(), '.skills-manager', 'tui-state.json')
  try {
    const state = JSON.parse(fs.readFileSync(stateFile, 'utf8')) as { descriptionLocale?: string }
    if (state.descriptionLocale?.trim()) return normalizeLocaleForCache(state.descriptionLocale)
  } catch {
    // fall back to environment
  }

  const envLocale = process.env.LC_ALL || process.env.LC_MESSAGES || process.env.LANG || Intl.DateTimeFormat().resolvedOptions().locale
  return normalizeLocaleForCache(envLocale.replace(/\.UTF-8$/i, ''))
}

export function resolveDescriptionLocale(metadata: Record<string, unknown> | undefined, description: string, fallback = 'en'): string {
  for (const key of EXPLICIT_LOCALE_KEYS) {
    const raw = metadata?.[key]
    if (typeof raw !== 'string') continue
    const normalized = normalizeExplicitLocale(raw)
    if (normalized) return normalized
  }

  return detectTextLocale(description) ?? normalizeLocaleIdentifier(fallback)
}

export function getCachedTranslation(
  skillID: string,
  sourceText: string,
  sourceLocale = 'en',
  targetLocale = getCurrentDescriptionLocale(),
): string | undefined {
  if (!sourceText.trim()) return undefined
  const cache = readCacheFile()
  if (!cache) return undefined

  const key = cacheKey(skillID, sourceText, sourceLocale, targetLocale)
  const entry = cache.entries[key]
  if (!entry || entry.translatorVersion !== TRANSLATOR_VERSION) return undefined
  return entry.translatedText
}

export function buildLocalizedDescription(skillID: string, baseDescription: string, baseDescriptionLocale = 'en'): {
  baseDescription: string
  baseDescriptionLocale: string
  localizedDescription?: string
  description: string
  isDescriptionTranslated: boolean
} {
  const normalizedSourceLocale = normalizeLocaleIdentifier(baseDescriptionLocale)
  const targetLocale = getCurrentDescriptionLocale()
  const localizedDescription = sameDisplayLanguage(normalizedSourceLocale, targetLocale)
    ? undefined
    : getCachedTranslation(skillID, baseDescription, normalizedSourceLocale, targetLocale)

  return {
    baseDescription,
    baseDescriptionLocale: normalizedSourceLocale,
    localizedDescription,
    description: localizedDescription ?? baseDescription,
    isDescriptionTranslated: Boolean(localizedDescription && localizedDescription !== baseDescription),
  }
}

function cacheKey(skillID: string, sourceText: string, sourceLocale: string, targetLocale: string): string {
  void skillID
  return `${sourceTextHash(sourceText)}|${normalizeLocaleForCache(sourceLocale)}|${normalizeLocaleForCache(targetLocale)}|${TRANSLATOR_VERSION}`
}

function sourceTextHash(sourceText: string): string {
  return crypto.createHash('sha256').update(sourceText).digest('hex')
}

function normalizeExplicitLocale(raw: string): string | undefined {
  const trimmed = raw.trim()
  if (!trimmed) return undefined
  const alias = LOCALE_ALIASES[trimmed.toLowerCase()]
  if (alias) return alias

  const normalized = normalizeLocaleIdentifier(trimmed)
  const primary = primaryLanguageCode(normalized)
  return primary.length === 2 || primary.length === 3 ? normalized : undefined
}

function normalizeLocaleIdentifier(locale: string): string {
  const trimmed = locale.trim().replace(/_/g, '-')
  if (!trimmed) return trimmed
  const alias = LOCALE_ALIASES[trimmed.toLowerCase()]
  if (alias) return alias

  const [language, ...rest] = trimmed.split('-')
  return [
    language.toLowerCase(),
    ...rest.map(part => {
      if (part.length === 4) return part[0].toUpperCase() + part.slice(1).toLowerCase()
      if (part.length === 2 || part.length === 3) return part.toUpperCase()
      return part
    }),
  ].join('-')
}

function normalizeLocaleForCache(locale: string): string {
  return normalizeLocaleIdentifier(locale).toLowerCase()
}

function detectTextLocale(text: string): string | undefined {
  const trimmed = text.trim()
  if (trimmed.length < 4) return undefined
  return detectCjkLocale(trimmed)
}

function detectCjkLocale(text: string): string | undefined {
  let hanCount = 0
  let kanaCount = 0
  let hangulCount = 0
  let simplifiedCount = 0
  let traditionalCount = 0
  let letterCount = 0

  for (const char of text) {
    if (/\p{L}/u.test(char)) letterCount += 1
    const codePoint = char.codePointAt(0) ?? 0
    if ((codePoint >= 0x3040 && codePoint <= 0x30ff) || (codePoint >= 0x31f0 && codePoint <= 0x31ff)) {
      kanaCount += 1
    } else if (
      (codePoint >= 0xac00 && codePoint <= 0xd7af) ||
      (codePoint >= 0x1100 && codePoint <= 0x11ff) ||
      (codePoint >= 0x3130 && codePoint <= 0x318f)
    ) {
      hangulCount += 1
    } else if (
      (codePoint >= 0x3400 && codePoint <= 0x4dbf) ||
      (codePoint >= 0x4e00 && codePoint <= 0x9fff) ||
      (codePoint >= 0xf900 && codePoint <= 0xfaff)
    ) {
      hanCount += 1
      if (SIMPLIFIED_CHINESE_CHARS.has(char)) simplifiedCount += 1
      if (TRADITIONAL_CHINESE_CHARS.has(char)) traditionalCount += 1
    }
  }

  const cjkCount = hanCount + kanaCount + hangulCount
  if (cjkCount < 2) return undefined
  if (cjkCount / Math.max(letterCount, 1) < 0.2) return undefined

  if (hangulCount > 0 && hangulCount >= hanCount && hangulCount >= kanaCount) return 'ko'
  if (kanaCount > 0) return 'ja'
  if (hanCount > 0) return traditionalCount > simplifiedCount ? 'zh-Hant' : 'zh-Hans'
  return undefined
}

function sameDisplayLanguage(lhs: string, rhs: string): boolean {
  const lhsPrimary = primaryLanguageCode(lhs)
  const rhsPrimary = primaryLanguageCode(rhs)
  if (!lhsPrimary || lhsPrimary !== rhsPrimary) return false

  if (lhsPrimary === 'zh') {
    const lhsScript = chineseScriptCode(lhs)
    const rhsScript = chineseScriptCode(rhs)
    if (lhsScript && rhsScript && lhsScript !== rhsScript) return false
  }

  return true
}

function primaryLanguageCode(locale: string): string {
  return normalizeLocaleIdentifier(locale).split('-')[0]?.toLowerCase() ?? ''
}

function chineseScriptCode(locale: string): 'Hans' | 'Hant' | undefined {
  const [language, ...rest] = normalizeLocaleIdentifier(locale).split('-')
  if (language !== 'zh') return undefined

  for (const part of rest) {
    const lower = part.toLowerCase()
    if (lower === 'hans') return 'Hans'
    if (lower === 'hant') return 'Hant'
    if (['cn', 'sg', 'my'].includes(lower)) return 'Hans'
    if (['tw', 'hk', 'mo'].includes(lower)) return 'Hant'
  }
  return undefined
}
