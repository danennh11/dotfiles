function cektweak --wraps='grep -c "maximized" ~/.config/hypr/user.lua; hyprctl configerrors' --description 'alias cektweak grep -c "maximized" ~/.config/hypr/user.lua; hyprctl configerrors'
    grep -c "maximized" ~/.config/hypr/user.lua; hyprctl configerrors $argv
end
