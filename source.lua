local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService');
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};
getgenv().Toggles = Toggles;
getgenv().Options = Options;

-- ============================================================
--  THEME  (change these to re-theme the whole UI)
-- ============================================================
local Library = {
    Registry = {};    RegistryMap = {};
    HudRegistry = {};

    FontColor       = Color3.fromRGB(235, 220, 255);   -- soft lavender-white
    MainColor       = Color3.fromRGB(26, 18, 40);      -- very dark purple
    BackgroundColor = Color3.fromRGB(16, 10, 26);      -- near-black purple
    AccentColor     = Color3.fromRGB(140, 60, 220);    -- vivid purple  ← change this to recolor everything
    OutlineColor    = Color3.fromRGB(65, 42, 95);      -- muted purple border
    RiskColor       = Color3.fromRGB(255, 55, 100);    -- hot-pink risk

    Black = Color3.new(0,0,0);
    Font  = Enum.Font.GothamSemibold;

    OpenedFrames = {};
    DependencyBoxes = {};
    Signals = {};
    ScreenGui = ScreenGui;
};

-- Rainbow hue tick
local RainbowStep, Hue = 0, 0;
table.insert(Library.Signals, RenderStepped:Connect(function(dt)
    RainbowStep = RainbowStep + dt;
    if RainbowStep >= 1/60 then
        RainbowStep = 0;
        Hue = Hue + 1/400;
        if Hue > 1 then Hue = 0; end;
        Library.CurrentRainbowHue   = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end;
end));

-- ============================================================
--  HELPERS
-- ============================================================
function Library:SafeCallback(f, ...)
    if not f then return; end;
    if not Library.NotifyOnError then return f(...); end;
    local ok, err = pcall(f, ...);
    if not ok then
        local _, i = err:find(":%d+: ");
        Library:Notify(i and err:sub(i+1) or err, 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then Library.SaveManager:Save(); end;
end;

function Library:Create(Class, Props)
    local inst = type(Class)=='string' and Instance.new(Class) or Class;
    for k,v in next, Props do inst[k]=v; end;
    return inst;
end;

function Library:ApplyTextStroke(inst)
    inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke',{Color=Color3.new(0,0,0);Thickness=1;LineJoinMode=Enum.LineJoinMode.Miter;Parent=inst;});
end;

function Library:CreateLabel(Props, IsHud)
    local lbl = Library:Create('TextLabel',{
        BackgroundTransparency=1;Font=Library.Font;TextColor3=Library.FontColor;TextSize=16;TextStrokeTransparency=0;
    });
    Library:ApplyTextStroke(lbl);
    Library:AddToRegistry(lbl,{TextColor3='FontColor';},IsHud);
    return Library:Create(lbl,Props);
end;

function Library:MakeDraggable(inst, cutoff)
    inst.Active = true;
    inst.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return; end;
        local op = Vector2.new(Mouse.X-inst.AbsolutePosition.X, Mouse.Y-inst.AbsolutePosition.Y);
        if op.Y > (cutoff or 40) then return; end;
        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            inst.Position = UDim2.new(0, Mouse.X-op.X+(inst.Size.X.Offset*inst.AnchorPoint.X),
                                      0, Mouse.Y-op.Y+(inst.Size.Y.Offset*inst.AnchorPoint.Y));
            RenderStepped:Wait();
        end;
    end);
end;

function Library:MapValue(v, minA, maxA, minB, maxB)
    return (1-((v-minA)/(maxA-minA)))*minB + ((v-minA)/(maxA-minA))*maxB;
end;

function Library:GetTextBounds(text, font, size, res)
    local b = TextService:GetTextSize(text, size, font, res or Vector2.new(1920,1080));
    return b.X, b.Y;
end;

function Library:GetDarkerColor(c)
    local h,s,v = Color3.toHSV(c); return Color3.fromHSV(h,s,v/1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(inst, props, isHud)
    local d = {Instance=inst;Properties=props;Idx=#Library.Registry+1;};
    table.insert(Library.Registry, d);
    Library.RegistryMap[inst] = d;
    if isHud then table.insert(Library.HudRegistry, d); end;
end;

function Library:RemoveFromRegistry(inst)
    local d = Library.RegistryMap[inst];
    if not d then return; end;
    for i=#Library.Registry,1,-1 do
        if Library.Registry[i]==d then table.remove(Library.Registry,i); end;
    end;
    for i=#Library.HudRegistry,1,-1 do
        if Library.HudRegistry[i]==d then table.remove(Library.HudRegistry,i); end;
    end;
    Library.RegistryMap[inst] = nil;
end;

function Library:UpdateColorsUsingRegistry()
    for _,obj in next, Library.Registry do
        for prop, colorIdx in next, obj.Properties do
            if type(colorIdx)=='string' then
                obj.Instance[prop] = Library[colorIdx];
            elseif type(colorIdx)=='function' then
                obj.Instance[prop] = colorIdx();
            end;
        end;
    end;
end;

function Library:GiveSignal(sig) table.insert(Library.Signals, sig); end;

function Library:Unload()
    for i=#Library.Signals,1,-1 do
        table.remove(Library.Signals,i):Disconnect();
    end;
    if Library.OnUnload then Library.OnUnload(); end;
    ScreenGui:Destroy();
end;

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(inst)
    if Library.RegistryMap[inst] then Library:RemoveFromRegistry(inst); end;
end));

-- ============================================================
--  NOTIFICATIONS
-- ============================================================
local NotifHolder = Library:Create('Frame',{
    BackgroundTransparency=1; Position=UDim2.new(1,-10,1,-10);
    Size=UDim2.fromOffset(270,0); AnchorPoint=Vector2.new(1,1); Parent=ScreenGui;
});
Library:Create('UIListLayout',{
    HorizontalAlignment=Enum.HorizontalAlignment.Center;
    SortOrder=Enum.SortOrder.LayoutOrder;
    VerticalAlignment=Enum.VerticalAlignment.Bottom;
    Padding=UDim.new(0,4); Parent=NotifHolder;
});

function Library:Notify(text, duration)
    duration = duration or 3;
    local f = Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Size=UDim2.fromOffset(270,0); AutomaticSize=Enum.AutomaticSize.Y; Parent=NotifHolder;
    });
    Library:Create('UIStroke',{Color=Library.AccentColor;Thickness=1;Parent=f;});
    Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=f;});
    Library:Create('Frame',{
        BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
        Size=UDim2.new(0,3,1,0); ZIndex=2; Parent=f;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=f:FindFirstChild('Frame');});
    local lbl = Library:Create('TextLabel',{
        BackgroundTransparency=1; Position=UDim2.fromOffset(10,6);
        Size=UDim2.new(1,-15,0,0); AutomaticSize=Enum.AutomaticSize.Y;
        Font=Library.Font; Text=text; TextColor3=Library.FontColor;
        TextSize=13; TextWrapped=true; TextXAlignment=Enum.TextXAlignment.Left; ZIndex=2; Parent=f;
    });
    Library:Create('UIPadding',{PaddingBottom=UDim.new(0,6);Parent=f;});
    task.delay(duration, function()
        TweenService:Create(f,   TweenInfo.new(0.4), {BackgroundTransparency=1;}):Play();
        TweenService:Create(lbl, TweenInfo.new(0.4), {TextTransparency=1;}):Play();
        task.wait(0.4); f:Destroy();
    end);
end;

-- ============================================================
--  WINDOW
-- ============================================================
function Library:CreateWindow(Info)
    local Window = {};
    local Tabs   = {};

    -- Main frame
    local WF = Library:Create('Frame',{
        BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
        Position=UDim2.fromOffset(Info.Position and Info.Position.X or 160, Info.Position and Info.Position.Y or 80);
        Size=UDim2.fromOffset(Info.Width or 560, Info.Height or 490); ZIndex=2; Parent=ScreenGui;
    });
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=WF;});
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=WF;});

    -- Title bar
    local TB = Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Size=UDim2.new(1,0,0,38); ZIndex=3; Parent=WF;
    });
    Library:Create('UICorner',{CornerRadius=UDim.new(0,6);Parent=TB;});
    Library:Create('UIGradient',{
        Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(88,28,155));
            ColorSequenceKeypoint.new(1, Library.MainColor);
        }); Rotation=90; Parent=TB;
    });
    -- Accent line
    Library:Create('Frame',{
        BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
        Position=UDim2.new(0,0,1,-2); Size=UDim2.new(1,0,0,2); ZIndex=4; Parent=TB;
    });
    -- Title text
    local TitleLbl = Library:Create('TextLabel',{
        BackgroundTransparency=1; Position=UDim2.fromOffset(14,0);
        Size=UDim2.new(1,-14,1,0); Font=Library.Font;
        Text='⬡  '..(Info.Name or 'Hook Rivals');
        TextColor3=Library.FontColor; TextSize=14; TextXAlignment=Enum.TextXAlignment.Left; ZIndex=4; Parent=TB;
    });
    Library:ApplyTextStroke(TitleLbl);

    Library:MakeDraggable(WF, 38);

    -- Left tab sidebar
    local Sidebar = Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderSizePixel=0;
        Position=UDim2.fromOffset(0,38); Size=UDim2.new(0,110,1,-38); ZIndex=3; Parent=WF;
    });
    Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=Sidebar;});
    Library:Create('UIListLayout',{SortOrder=Enum.SortOrder.LayoutOrder;Padding=UDim.new(0,3);Parent=Sidebar;});
    Library:Create('UIPadding',{PaddingTop=UDim.new(0,8);PaddingLeft=UDim.new(0,6);PaddingRight=UDim.new(0,6);Parent=Sidebar;});

    -- Content area
    local CA = Library:Create('Frame',{
        BackgroundTransparency=1;
        Position=UDim2.fromOffset(110,38); Size=UDim2.new(1,-110,1,-38); ZIndex=3; Parent=WF;
    });

    -- ============================================================
    --  AddTab
    -- ============================================================
    function Window:AddTab(name)
        local Tab = {};

        local TabBtn = Library:Create('TextButton',{
            BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
            Size=UDim2.new(1,0,0,28); Font=Library.Font;
            Text=name; TextColor3=Color3.fromRGB(150,130,190); TextSize=13; ZIndex=4; Parent=Sidebar;
        });
        Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=TabBtn;});

        local TabFrame = Library:Create('ScrollingFrame',{
            BackgroundTransparency=1; BorderSizePixel=0;
            Size=UDim2.new(1,0,1,0); CanvasSize=UDim2.fromOffset(0,0);
            AutomaticCanvasSize=Enum.AutomaticSize.Y; ScrollBarThickness=3;
            ScrollBarImageColor3=Library.AccentColor; Visible=false; ZIndex=3; Parent=CA;
        });
        Library:Create('UIPadding',{PaddingTop=UDim.new(0,8);PaddingLeft=UDim.new(0,8);PaddingRight=UDim.new(0,8);Parent=TabFrame;});
        Library:Create('UIListLayout',{SortOrder=Enum.SortOrder.LayoutOrder;Padding=UDim.new(0,6);Parent=TabFrame;});

        local function Select()
            for _,t in ipairs(Tabs) do
                TweenService:Create(t.Btn,TweenInfo.new(0.12),{BackgroundColor3=Library.BackgroundColor;}):Play();
                t.Btn.TextColor3 = Color3.fromRGB(150,130,190);
                t.Frame.Visible = false;
            end;
            TweenService:Create(TabBtn,TweenInfo.new(0.12),{BackgroundColor3=Library.AccentColor;}):Play();
            TabBtn.TextColor3 = Color3.fromRGB(255,255,255);
            TabFrame.Visible = true;
        end;
        TabBtn.MouseButton1Click:Connect(Select);
        table.insert(Tabs,{Btn=TabBtn;Frame=TabFrame;});
        if #Tabs==1 then Select(); end;

        -- ============================================================
        --  AddSection
        -- ============================================================
        function Tab:AddSection(secName)
            local Sec = {};

            local SF = Library:Create('Frame',{
                BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,0,0); AutomaticSize=Enum.AutomaticSize.Y; ZIndex=3; Parent=TabFrame;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=SF;});
            Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=SF;});

            -- Section header
            local SH = Library:Create('Frame',{
                BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
                Size=UDim2.new(1,0,0,22); ZIndex=4; Parent=SF;
            });
            Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=SH;});
            -- fill bottom corners of header
            Library:Create('Frame',{
                BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
                Position=UDim2.new(0,0,0.5,0); Size=UDim2.new(1,0,0.5,0); ZIndex=4; Parent=SH;
            });
            Library:Create('TextLabel',{
                BackgroundTransparency=1; Size=UDim2.new(1,0,1,0);
                Font=Library.Font; Text=secName; TextColor3=Color3.fromRGB(255,255,255);
                TextSize=13; ZIndex=5; Parent=SH;
            });

            local SC = Library:Create('Frame',{
                BackgroundTransparency=1; Position=UDim2.fromOffset(0,22);
                Size=UDim2.new(1,0,0,0); AutomaticSize=Enum.AutomaticSize.Y; ZIndex=4; Parent=SF;
            });
            Library:Create('UIListLayout',{SortOrder=Enum.SortOrder.LayoutOrder;Padding=UDim.new(0,4);Parent=SC;});
            Library:Create('UIPadding',{
                PaddingTop=UDim.new(0,5);PaddingBottom=UDim.new(0,5);
                PaddingLeft=UDim.new(0,6);PaddingRight=UDim.new(0,6); Parent=SC;
            });

            -- ----------------------------------------------------------
            --  Toggle
            -- ----------------------------------------------------------
            function Sec:AddToggle(idx, info)
                local T = { Value=info.Default or false; Callback=info.Callback or function() end; };
                Toggles[idx] = T;

                local TF = Library:Create('Frame',{BackgroundTransparency=1;Size=UDim2.new(1,0,0,22);ZIndex=5;Parent=SC;});

                local TBtn = Library:Create('Frame',{
                    AnchorPoint=Vector2.new(1,0.5); BorderSizePixel=0;
                    BackgroundColor3=T.Value and Library.AccentColor or Library.OutlineColor;
                    Position=UDim2.new(1,-2,0.5,0); Size=UDim2.fromOffset(34,16); ZIndex=6; Parent=TF;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(1,0);Parent=TBtn;});

                local TKnob = Library:Create('Frame',{
                    AnchorPoint=Vector2.new(0.5,0.5); BackgroundColor3=Color3.fromRGB(255,255,255);
                    BorderSizePixel=0;
                    Position=T.Value and UDim2.new(0.75,0,0.5,0) or UDim2.new(0.25,0,0.5,0);
                    Size=UDim2.fromOffset(12,12); ZIndex=7; Parent=TBtn;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(1,0);Parent=TKnob;});

                Library:CreateLabel({
                    Size=UDim2.new(1,-40,1,0); Text=info.Title or idx;
                    TextSize=13; TextXAlignment=Enum.TextXAlignment.Left; ZIndex=6; Parent=TF;
                });

                local function SetValue(v)
                    T.Value = v;
                    TweenService:Create(TBtn, TweenInfo.new(0.15),{BackgroundColor3=v and Library.AccentColor or Library.OutlineColor;}):Play();
                    TweenService:Create(TKnob,TweenInfo.new(0.15),{Position=v and UDim2.new(0.75,0,0.5,0) or UDim2.new(0.25,0,0.5,0);}):Play();
                    Library:SafeCallback(T.Callback, v);
                    Library:AttemptSave();
                end;
                T.SetValue = SetValue;

                TF.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then SetValue(not T.Value); end;
                end);
                if info.Tooltip then Library:AddToolTip(info.Tooltip, TF); end;
                return T;
            end;

            -- ----------------------------------------------------------
            --  Slider
            -- ----------------------------------------------------------
            function Sec:AddSlider(idx, info)
                local S = {
                    Value   = info.Default or info.Min or 0;
                    Min     = info.Min or 0;
                    Max     = info.Max or 100;
                    Rounding= info.Rounding or 0;
                    Callback= info.Callback or function() end;
                };
                Options[idx] = S;

                local SF2 = Library:Create('Frame',{BackgroundTransparency=1;Size=UDim2.new(1,0,0,36);ZIndex=5;Parent=SC;});
                local Lbl = Library:CreateLabel({
                    Size=UDim2.new(1,0,0,16); Text=(info.Title or idx)..': '..tostring(S.Value);
                    TextSize=13; TextXAlignment=Enum.TextXAlignment.Left; ZIndex=6; Parent=SF2;
                });
                local Track = Library:Create('Frame',{
                    BackgroundColor3=Library.OutlineColor; BorderSizePixel=0;
                    Position=UDim2.fromOffset(0,20); Size=UDim2.new(1,0,0,8); ZIndex=6; Parent=SF2;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(1,0);Parent=Track;});
                local Fill = Library:Create('Frame',{
                    BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
                    Size=UDim2.new((S.Value-S.Min)/(S.Max-S.Min),0,1,0); ZIndex=7; Parent=Track;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(1,0);Parent=Fill;});

                local function SetValue(v)
                    v = math.clamp(math.round(v*(10^S.Rounding))/(10^S.Rounding), S.Min, S.Max);
                    S.Value = v;
                    Lbl.Text = (info.Title or idx)..': '..tostring(v);
                    Fill.Size = UDim2.new((v-S.Min)/(S.Max-S.Min),0,1,0);
                    Library:SafeCallback(S.Callback, v);
                    Library:AttemptSave();
                end;
                S.SetValue = SetValue;

                local drag = false;
                Track.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; end;
                end);
                Track.InputEnded:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false; end;
                end);
                Library:GiveSignal(RenderStepped:Connect(function()
                    if drag then
                        local rel = math.clamp((Mouse.X-Track.AbsolutePosition.X)/Track.AbsoluteSize.X, 0, 1);
                        SetValue(Library:MapValue(rel, 0,1, S.Min, S.Max));
                    end;
                end));
                return S;
            end;

            -- ----------------------------------------------------------
            --  ColorPicker
            -- ----------------------------------------------------------
            function Sec:AddColorPicker(idx, info)
                local P = { Value=info.Default or Color3.fromRGB(255,255,255); Callback=info.Callback or function() end; };
                Options[idx] = P;

                local PF = Library:Create('Frame',{BackgroundTransparency=1;Size=UDim2.new(1,0,0,22);ZIndex=5;Parent=SC;});
                Library:CreateLabel({
                    Size=UDim2.new(1,-36,1,0); Text=info.Title or idx;
                    TextSize=13; TextXAlignment=Enum.TextXAlignment.Left; ZIndex=6; Parent=PF;
                });
                local Disp = Library:Create('Frame',{
                    AnchorPoint=Vector2.new(1,0.5); BackgroundColor3=P.Value; BorderSizePixel=0;
                    Position=UDim2.new(1,-2,0.5,0); Size=UDim2.fromOffset(30,14); ZIndex=6; Parent=PF;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=Disp;});
                Library:Create('UIStroke',{Color=Library.OutlineColor;Thickness=1;Parent=Disp;});

                local H,S,V = Color3.toHSV(P.Value);

                local Popup = Library:Create('Frame',{
                    BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                    Position=UDim2.fromOffset(Disp.AbsolutePosition.X, Disp.AbsolutePosition.Y+20);
                    Size=UDim2.fromOffset(210,210); Visible=false; ZIndex=50; Parent=ScreenGui;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,5);Parent=Popup;});
                Library:Create('UIStroke',{Color=Library.AccentColor;Thickness=1;Parent=Popup;});

                Disp:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
                    Popup.Position=UDim2.fromOffset(Disp.AbsolutePosition.X, Disp.AbsolutePosition.Y+20);
                end);

                local SVM = Library:Create('ImageLabel',{
                    BorderSizePixel=0; Position=UDim2.fromOffset(6,6);
                    Size=UDim2.fromOffset(170,140); ZIndex=51;
                    Image='rbxassetid://4155801252'; Parent=Popup;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=SVM;});

                local SVCursor = Library:Create('Frame',{
                    AnchorPoint=Vector2.new(0.5,0.5); BackgroundColor3=Color3.new(1,1,1);
                    BorderSizePixel=0; Position=UDim2.new(S,0,1-V,0);
                    Size=UDim2.fromOffset(8,8); ZIndex=52; Parent=SVM;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(1,0);Parent=SVCursor;});

                local HueBar = Library:Create('ImageLabel',{
                    BorderSizePixel=0; Position=UDim2.fromOffset(6,152);
                    Size=UDim2.fromOffset(170,14); ZIndex=51;
                    Image='rbxassetid://698052001'; Parent=Popup;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(1,0);Parent=HueBar;});

                local HueCursor = Library:Create('Frame',{
                    AnchorPoint=Vector2.new(0.5,0.5); BackgroundColor3=Color3.new(1,1,1);
                    BorderSizePixel=0; Position=UDim2.new(H,0,0.5,0);
                    Size=UDim2.fromOffset(6,18); ZIndex=52; Parent=HueBar;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,2);Parent=HueCursor;});

                local HexBox = Library:Create('TextBox',{
                    BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
                    Position=UDim2.fromOffset(6,172); Size=UDim2.fromOffset(170,22);
                    Font=Library.Font; Text='#FFFFFF'; TextColor3=Library.FontColor;
                    TextSize=12; ZIndex=51; Parent=Popup;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=HexBox;});
                Library:Create('UIStroke',{Color=Library.OutlineColor;Parent=HexBox;});

                local function Update()
                    local col = Color3.fromHSV(H,S,V);
                    P.Value = col;
                    Disp.BackgroundColor3 = col;
                    SVM.ImageColor3 = Color3.fromHSV(H,1,1);
                    SVCursor.Position = UDim2.new(S,0,1-V,0);
                    HueCursor.Position = UDim2.new(H,0,0.5,0);
                    HexBox.Text = string.format('#%02X%02X%02X',
                        math.floor(col.R*255), math.floor(col.G*255), math.floor(col.B*255));
                    Library:SafeCallback(P.Callback, col);
                    Library:AttemptSave();
                end;

                local dragSV, dragH = false, false;
                SVM.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragSV=true; end; end);
                SVM.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragSV=false; end; end);
                HueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragH=true; end; end);
                HueBar.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragH=false; end; end);
                Library:GiveSignal(RenderStepped:Connect(function()
                    if dragSV then
                        S = math.clamp((Mouse.X-SVM.AbsolutePosition.X)/SVM.AbsoluteSize.X,0,1);
                        V = 1-math.clamp((Mouse.Y-SVM.AbsolutePosition.Y)/SVM.AbsoluteSize.Y,0,1);
                        Update();
                    end;
                    if dragH then
                        H = math.clamp((Mouse.X-HueBar.AbsolutePosition.X)/HueBar.AbsoluteSize.X,0,1);
                        Update();
                    end;
                end));
                HexBox.FocusLost:Connect(function()
                    local t = HexBox.Text:gsub('#','');
                    if #t==6 then
                        local r,g,b = tonumber(t:sub(1,2),16), tonumber(t:sub(3,4),16), tonumber(t:sub(5,6),16);
                        if r and g and b then
                            H,S,V = Color3.toHSV(Color3.fromRGB(r,g,b)); Update();
                        end;
                    end;
                end);

                local open = false;
                Disp.InputBegan:Connect(function(i)
                    if i.UserInputType==Enum.UserInputType.MouseButton1 then
                        open = not open; Popup.Visible = open;
                        if open then Library.OpenedFrames[Popup]=true; else Library.OpenedFrames[Popup]=nil; end;
                    end;
                end);

                Update();
                function P:SetValue(col)
                    H,S,V = Color3.toHSV(col); Update();
                end;
                return P;
            end;

            -- ----------------------------------------------------------
            --  Dropdown
            -- ----------------------------------------------------------
            function Sec:AddDropdown(idx, info)
                local D = {Value=info.Default; Options=info.Options or {}; Callback=info.Callback or function() end;};
                Options[idx] = D;

                local DF = Library:Create('Frame',{BackgroundTransparency=1;Size=UDim2.new(1,0,0,40);ZIndex=5;Parent=SC;});
                Library:CreateLabel({
                    Size=UDim2.new(1,0,0,16); Text=info.Title or idx;
                    TextSize=13; TextXAlignment=Enum.TextXAlignment.Left; ZIndex=6; Parent=DF;
                });
                local DBtn = Library:Create('TextButton',{
                    BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
                    Position=UDim2.fromOffset(0,18); Size=UDim2.new(1,0,0,20);
                    Font=Library.Font; Text='  '..(tostring(D.Value or 'Select...')..'  ▾');
                    TextColor3=Library.FontColor; TextSize=12; TextXAlignment=Enum.TextXAlignment.Left;
                    ZIndex=6; Parent=DF;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=DBtn;});
                Library:Create('UIStroke',{Color=Library.OutlineColor;Parent=DBtn;});

                local DList = Library:Create('Frame',{
                    BackgroundColor3=Library.MainColor; BorderSizePixel=0;
                    Position=UDim2.fromOffset(DBtn.AbsolutePosition.X, DBtn.AbsolutePosition.Y+22);
                    Size=UDim2.fromOffset(DBtn.AbsoluteSize.X,0); AutomaticSize=Enum.AutomaticSize.Y;
                    Visible=false; ZIndex=60; Parent=ScreenGui;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=DList;});
                Library:Create('UIStroke',{Color=Library.AccentColor;Thickness=1;Parent=DList;});
                Library:Create('UIListLayout',{SortOrder=Enum.SortOrder.LayoutOrder;Parent=DList;});
                Library:Create('UIPadding',{PaddingTop=UDim.new(0,3);PaddingBottom=UDim.new(0,3);Parent=DList;});

                DBtn:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
                    DList.Position = UDim2.fromOffset(DBtn.AbsolutePosition.X, DBtn.AbsolutePosition.Y+22);
                    DList.Size     = UDim2.fromOffset(DBtn.AbsoluteSize.X,0);
                end);

                local function SetValue(v)
                    D.Value=v; DBtn.Text='  '..tostring(v)..'  ▾';
                    DList.Visible=false; Library.OpenedFrames[DList]=nil;
                    Library:SafeCallback(D.Callback,v); Library:AttemptSave();
                end;
                D.SetValue = SetValue;

                local function Refresh()
                    for _,c in ipairs(DList:GetChildren()) do
                        if c:IsA('TextButton') then c:Destroy(); end;
                    end;
                    for _,opt in ipairs(D.Options) do
                        local OB = Library:Create('TextButton',{
                            BackgroundTransparency=1; Size=UDim2.new(1,0,0,22);
                            Font=Library.Font; Text='  '..tostring(opt);
                            TextColor3=Library.FontColor; TextSize=12;
                            TextXAlignment=Enum.TextXAlignment.Left; ZIndex=61; Parent=DList;
                        });
                        OB.MouseEnter:Connect(function() OB.BackgroundTransparency=0; OB.BackgroundColor3=Library.AccentColor; end);
                        OB.MouseLeave:Connect(function() OB.BackgroundTransparency=1; end);
                        OB.MouseButton1Click:Connect(function() SetValue(opt); end);
                    end;
                end;
                Refresh();

                local open = false;
                DBtn.MouseButton1Click:Connect(function()
                    open=not open; DList.Visible=open;
                    if open then Library.OpenedFrames[DList]=true; else Library.OpenedFrames[DList]=nil; end;
                end);
                function D:SetOptions(opts) D.Options=opts; Refresh(); end;
                return D;
            end;

            -- ----------------------------------------------------------
            --  Label
            -- ----------------------------------------------------------
            function Sec:AddLabel(text)
                return Library:CreateLabel({
                    Size=UDim2.new(1,0,0,18); Text=text; TextSize=12;
                    TextXAlignment=Enum.TextXAlignment.Left; ZIndex=6; Parent=SC;
                });
            end;

            -- ----------------------------------------------------------
            --  Button
            -- ----------------------------------------------------------
            function Sec:AddButton(info)
                local Btn = Library:Create('TextButton',{
                    BackgroundColor3=Library.AccentColor; BorderSizePixel=0;
                    Size=UDim2.new(1,0,0,24); Font=Library.Font;
                    Text=info.Title or 'Button'; TextColor3=Color3.fromRGB(255,255,255);
                    TextSize=13; ZIndex=6; Parent=SC;
                });
                Library:Create('UICorner',{CornerRadius=UDim.new(0,4);Parent=Btn;});
                Btn.MouseEnter:Connect(function()
                    TweenService:Create(Btn,TweenInfo.new(0.1),{BackgroundColor3=Library:GetDarkerColor(Library.AccentColor);}):Play();
                end);
                Btn.MouseLeave:Connect(function()
                    TweenService:Create(Btn,TweenInfo.new(0.1),{BackgroundColor3=Library.AccentColor;}):Play();
                end);
                Btn.MouseButton1Click:Connect(function() Library:SafeCallback(info.Callback); end);
                return Btn;
            end;

            -- ----------------------------------------------------------
            --  Textbox
            -- ----------------------------------------------------------
            function Sec:AddTextbox(idx, info)
                local T2 = {Value=info.Default or ''; Callback=info.Callback or function() end;};
                Options[idx] = T2;
                local TF2 = Library:Create('Frame',{BackgroundTransparency=1;Size=UDim2.new(1,0,0,40);ZIndex=5;Parent=SC;});
                Library:CreateLabel({
                    Size=UDim2.new(1,0,0,16); Text=info.Title or idx;
                    TextSize=13; TextXAlignment=Enum.TextXAlignment.Left; ZIndex=6; Parent=TF2;
                });
                local TBx = Library:Create('TextBox',{
                    BackgroundColor3=Library.BackgroundColor; BorderSizePixel=0;
                    Position=UDim2.fromOffset(0,18); Size=UDim2.new(1,0,0,20);
                    Font=Library.Font; PlaceholderText=info.Placeholder or '';
                    Text=T2.Value; TextColor3=Library.FontColor; TextSize=12;
                    TextXAlignment=Enum.TextXAlignment.Left; ZIndex=6; Parent=TF2;
                });
                Library:Create('UIPadding',{PaddingLeft=UDim.new(0,5);Parent=TBx;});
                Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=TBx;});
                Library:Create('UIStroke',{Color=Library.OutlineColor;Parent=TBx;});
                TBx.FocusLost:Connect(function()
                    T2.Value=TBx.Text; Library:SafeCallback(T2.Callback,TBx.Text); Library:AttemptSave();
                end);
                return T2;
            end;

            return Sec;
        end;

        return Tab;
    end;

    function Window:Close() WF.Visible=false; end;
    function Window:Open()  WF.Visible=true;  end;

    return Window;
end;

function Library:AddToolTip(infoStr, hoverInst)
    local x,y = Library:GetTextBounds(infoStr, Library.Font, 14);
    local Tip = Library:Create('Frame',{
        BackgroundColor3=Library.MainColor; BorderColor3=Library.OutlineColor;
        Size=UDim2.fromOffset(x+5,y+4); ZIndex=100; Parent=ScreenGui; Visible=false;
    });
    Library:Create('UIStroke',{Color=Library.OutlineColor;Parent=Tip;});
    Library:Create('UICorner',{CornerRadius=UDim.new(0,3);Parent=Tip;});
    local TipLbl = Library:CreateLabel({
        Position=UDim2.fromOffset(3,1); Size=UDim2.fromOffset(x,y);
        TextSize=14; Text=infoStr; TextXAlignment=Enum.TextXAlignment.Left;
        ZIndex=101; Parent=Tip;
    });
    local hovering = false;
    hoverInst.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return; end;
        hovering=true; Tip.Position=UDim2.fromOffset(Mouse.X+15,Mouse.Y+12); Tip.Visible=true;
        while hovering do
            RunService.Heartbeat:Wait();
            Tip.Position=UDim2.fromOffset(Mouse.X+15,Mouse.Y+12);
        end;
    end);
    hoverInst.MouseLeave:Connect(function() hovering=false; Tip.Visible=false; end);
end;

return Library;
