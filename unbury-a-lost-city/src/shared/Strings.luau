--!strict
--[[
	Strings — player-facing text. Korean for ko-* locales, English otherwise.
	Keep every line short: the HUD only ever shows one instruction at a time.
]]

local Strings = {}

export type Table = {
	Title: string,
	Intro: string,
	ObjectiveFindSpot: string,
	ObjectiveUncover: string,
	ObjectiveDone: string,
	ObjectiveNoPlot: string,
	ToastGlimpse: string,
	ToastDiscovered: string,
	HintMouse: string,
	HintTouch: string,
	HintGamepad: string,
	DigButton: string,
	MarkerLabel: string,
	ArtifactNames: { [string]: string },
	DebugHelp: string,
}

local KOREAN: Table = {
	Title = "UNBURY A LOST CITY!",
	Intro = "모래 아래에 잊혀진 도시가 잠들어 있습니다.",
	ObjectiveFindSpot = "표시된 곳을 파 보세요",
	ObjectiveUncover = "주변을 더 파서 유물을 드러내세요",
	ObjectiveDone = "유물 발견! 자유롭게 더 파 보세요",
	ObjectiveNoPlot = "이 서버에 빈 발굴 구역이 없습니다",
	ToastGlimpse = "모래 속에서 무언가 반짝입니다…",
	ToastDiscovered = "발견: %s",
	HintMouse = "마우스 왼쪽 버튼을 누르고 있으면 계속 팝니다",
	HintTouch = "파기 버튼을 누르고 있으세요 · 모래를 탭하면 조준",
	HintGamepad = "R2를 누르고 있으면 계속 팝니다",
	DigButton = "파기",
	MarkerLabel = "여기를 파세요",
	ArtifactNames = {
		SunIdol = "황금 태양 우상",
	},
	DebugHelp = "[Studio] F2 도구 레벨 전환 · F4 발굴 구역 초기화 · F3 성능 표시",
}

local ENGLISH: Table = {
	Title = "UNBURY A LOST CITY!",
	Intro = "A forgotten city sleeps beneath the sand.",
	ObjectiveFindSpot = "Dig at the marked spot",
	ObjectiveUncover = "Dig around it to uncover the relic",
	ObjectiveDone = "Relic found! Keep digging freely",
	ObjectiveNoPlot = "No free dig site on this server",
	ToastGlimpse = "Something glints beneath the sand…",
	ToastDiscovered = "Discovered: %s",
	HintMouse = "Hold the left mouse button to dig",
	HintTouch = "Hold DIG to dig · Tap the sand to aim",
	HintGamepad = "Hold R2 to dig",
	DigButton = "DIG",
	MarkerLabel = "Dig here",
	ArtifactNames = {
		SunIdol = "Golden Sun Idol",
	},
	DebugHelp = "[Studio] F2 toggle tool level · F4 reset dig site · F3 stats",
}

function Strings.forLocale(localeId: string?): Table
	if localeId ~= nil and string.sub(string.lower(localeId), 1, 2) == "ko" then
		return KOREAN
	end
	return ENGLISH
end

return Strings
