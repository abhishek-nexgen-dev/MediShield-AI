const symbols = {
  activity: '\ueaa2', // monitor_heart
  hospital: '\ue548', // local_hospital
  shield: '\ue8e8', // verified_user
  users: '\ue7ef', // group
  file: '\ue873', // description
  link: '\ue157', // link
  sparkles: '\ue65f', // auto_awesome
  mic: '\ue029', // mic
  check: '\ue5ca', // check
  clock: '\ue8b5', // schedule
  layers: '\ue53b', // layers
  heart: '\ue87d', // favorite
  mail: '\ue0e1', // mail_outline
  lock: '\ue899', // lock_outline
  theme: '\ueb37', // contrast
  menu: '\ue5d2', // menu
  close: '\ue5cd', // close
} as const;

type IconProps = {
  name: keyof typeof symbols;
  size?: 15 | 17 | 20 | 22;
};

const iconSizes = {
  15: 'text-[15px]',
  17: 'text-[17px]',
  20: 'text-xl',
  22: 'text-[22px]',
};

export function Icon({ name, size = 20 }: IconProps) {
  return (
    <span className={`inline-flex shrink-0 items-center justify-center font-symbols font-normal !leading-none ${iconSizes[size]}`} aria-hidden="true">
      {symbols[name]}
    </span>
  );
}
