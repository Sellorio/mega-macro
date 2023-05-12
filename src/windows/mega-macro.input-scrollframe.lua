function MegaMacro_EditBox_OnTabPressed(self)
    if (self.previousEditBox and IsShiftKeyDown()) then
        self.previousEditBox:SetFocus();
    elseif (self.nextEditBox) then
        self.nextEditBox:SetFocus();
    end
end

function MegaMacro_EditBox_ClearFocus(self)
    self:ClearFocus();
end

function MegaMacro_EditBox_HighlightText(self)
    self:HighlightText();
end

function MegaMacro_EditBox_ClearHighlight(self)
    self:HighlightText(0, 0);
end

function MegaMacro_ScrollFrame_OnLoad(self)
    if not self.noScrollBar then
        local scrollBarTemplate = self.scrollBarTemplate or SCROLL_FRAME_SCROLL_BAR_TEMPLATE;
        if not scrollBarTemplate then
            error("SCROLL_FRAME_SCROLL_BAR_TEMPLATE undefined. Check ScrollDefine.lua")
        end

        local left = self.scrollBarX or SCROLL_FRAME_SCROLL_BAR_OFFSET_LEFT;
        if not left then
            error("SCROLL_FRAME_SCROLL_BAR_OFFSET_LEFT undefined. Check ScrollDefine.lua")
        end

        local top = self.scrollBarTopY or SCROLL_FRAME_SCROLL_BAR_OFFSET_TOP;
        if not top then
            error("SCROLL_FRAME_SCROLL_BAR_OFFSET_TOP undefined. Check ScrollDefine.lua")
        end

        local bottom = self.scrollBarBottomY or SCROLL_FRAME_SCROLL_BAR_OFFSET_BOTTOM;
        if not bottom then
            error("SCROLL_FRAME_SCROLL_BAR_OFFSET_BOTTOM undefined. Check ScrollDefine.lua")
        end

        self.ScrollBar = CreateFrame("EventFrame", nil, self, scrollBarTemplate);
        self.ScrollBar:SetHideIfUnscrollable(self.scrollBarHideIfUnscrollable);
        self.ScrollBar:SetHideTrackIfThumbExceedsTrack(self.scrollBarHideTrackIfThumbExceedsTrack);
        self.ScrollBar:SetPoint("TOPLEFT", self, "TOPRIGHT", left, top);
        self.ScrollBar:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", left, bottom);
        self.ScrollBar:Show();

        ScrollUtil.InitScrollFrameWithScrollBar(self, self.ScrollBar);

        self.ScrollBar:Update();
    end
end

function MegaMacro_ScrollingEdit_OnTextChanged(self, scrollFrame)
    -- force an update when the text changes
    self.handleCursorChange = true;
    MegaMacro_ScrollingEdit_OnUpdate(self, 0, scrollFrame);
end

function MegaMacro_ScrollingEdit_OnLoad(self)
    MegaMacro_ScrollingEdit_SetCursorOffsets(self, 0, 0);
end

function MegaMacro_ScrollingEdit_SetCursorOffsets(self, offset, height)
    self.cursorOffset = offset;
    self.cursorHeight = height;
end

function MegaMacro_ScrollingEdit_OnCursorChanged(self, x, y, w, h)
    MegaMacro_ScrollingEdit_SetCursorOffsets(self, y, h);
    self.handleCursorChange = true;
end

-- NOTE: If your edit box never shows partial lines of text, then this function will not work when you use
-- your mouse to move the edit cursor. You need the edit box to cut lines of text so that you can use your
-- mouse to highlight those partially-seen lines; otherwise you won't be able to use the mouse to move the
-- cursor above or below the current scroll area of the edit box.
function MegaMacro_ScrollingEdit_OnUpdate(self, elapsed, scrollFrame)
    if (not scrollFrame) then
        scrollFrame = self:GetParent();
    end

    local hasScrollableExtent = scrollFrame.ScrollBar:HasScrollableExtent();
    if (not hasScrollableExtent) then
        -- Return if the scroll frame has no scroll bar or if the scroll bar has no scrollable extent.
        return;
    end

    local formattedScrollFrame = _G["MegaMacro_FormattedFrameScrollFrame"];
    if not formattedScrollFrame then
        error("MegaMacro_FormattedFrameScrollFrame undefined. Check ScrollDefine.lua")
    end

    local scroll = scrollFrame:GetVerticalScroll();
    local formattedScroll = formattedScrollFrame:GetVerticalScroll();

    if (scroll ~= formattedScroll) then
        formattedScrollFrame:SetVerticalScroll(scroll);
    end

    if (self.handleCursorChange) then
        local height, range, size, cursorOffset;

        height = scrollFrame:GetHeight();
        range = scrollFrame:GetVerticalScrollRange();
        size = height + range;
        cursorOffset = -self.cursorOffset;

        if (math.floor(height) <= 0 or math.floor(range) <= 0) then
            --Frame has no area, nothing to calculate.
            return;
        end

        while (cursorOffset < scroll) do
            scroll = (scroll - (height / 2));
            if (scroll < 0) then
                scroll = 0;
            end
            scrollFrame:SetVerticalScroll(scroll);
            formattedScrollFrame:SetVerticalScroll(scroll);
        end

        -- If the cursor is below the scroll area, scroll down until it's at the bottom of the scroll area.
        while ((cursorOffset + self.cursorHeight) > (scroll + height) and scroll < range) do
            scroll = (scroll + (height / 2));
            -- Don't scroll past the end of the text
            if (scroll > range) then
                scroll = range;
            end
            scrollFrame:SetVerticalScroll(scroll);
            formattedScrollFrame:SetVerticalScroll(scroll);
        end

        self.handleCursorChange = false;
    end
end

function MegaMacro_InputScrollFrame_OnLoad(self)
    -- self.scrollBarX = -10;
    -- self.scrollBarTopY = -1;
    -- self.scrollBarBottomY = -3;
    -- self.scrollBarHideIfUnscrollable = true;

    MegaMacro_ScrollFrame_OnLoad(self);

    self.EditBox:SetWidth(self:GetWidth() - 18);
    self.EditBox:SetMaxLetters(self.maxLetters);
end

function MegaMacro_InputScrollFrame_OnMouseDown(self)
    self.EditBox:SetFocus();
end

MegaMacro_InputScrollFrame_OnTabPressed = MegaMacro_EditBox_OnTabPressed;

function MegaMacro_InputScrollFrame_OnUpdate(self, elapsed)
    MegaMacro_ScrollingEdit_OnUpdate(self, elapsed, self:GetParent());
end

function MegaMacro_InputScrollFrame_OnEscapePressed(self)
    self:ClearFocus();
end
