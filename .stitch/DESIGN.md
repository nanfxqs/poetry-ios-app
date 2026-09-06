---
name: 诗词 · 纸白淡墨
colors:
  background: '#FAFAF8'
  surface: '#FAFAF8'
  on-surface: '#302E2C'
  primary: '#9C4946'
  secondary: '#756E68'
  outline-variant: '#E5E0DA'
  surface-container-low: '#F4F3F0'
---

# 诗词 · 纸白淡墨

## Visual theme
已确认的 D 页边入景。中国古诗词阅读，以安静纸白、墨灰文字和少量胭脂红点缀传达文学与浪漫感。避免泛黄底色、大面积绿色、厚卡片与夸张阴影。保留清楚的结构和阅读节奏。

## Color roles
纸白 #FAFAF8 为阅读底色；墨灰 #302E2C 为主要文本；暖灰 #756E68 为辅助信息；胭脂 #9C4946 用于选中态与少量重点；淡灰 #E5E0DA 为分隔线；地图示意底为 #F4F3F0。

## Typography
正文与文学标题采用 Noto Serif CJK SC / 宋体风格，控件采用 Noto Sans CJK SC / 系统无衬线。诗句 23px / 47px；作品标题 18–22px；页面标题 25px；控件 14–15px；辅助信息 11–13px。字体需支持完整中文。

## Layout
iPhone 15 Pro：393 × 852 逻辑视口，顶部 59px、底部 34px 安全区示意。正文左右 28px。底部导航总高 83px，今日／探索／诗集固定三入口。内容区域独立滚动，不被底部导航遮挡。图标操作保持 44px 点击区。

## Components
页角小幅淡墨，静止且不覆盖文字。列表用细线分隔。声音只在页角显示图标；返回仅箭头。关系图用稀疏节点、作品依据与一个读诗动作。人名可点选。地图明确区分诗中之地与写作地。未知写作地显示空态，不编造坐标。诗集是整首作品收藏列表。

## Interaction and export
必要过渡，无持续动效。环境声默认关闭。当前为可审阅原型，真实地图、资料与备份尚未接入。导出静态 HTML 内联 CSS/SVG/图片，3 倍截图 1179 × 2556，不放大旧缩略图。
