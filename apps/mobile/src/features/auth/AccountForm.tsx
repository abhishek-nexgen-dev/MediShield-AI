import { Link } from 'expo-router';
import { useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';

export type AccountMode = 'login' | 'recovery' | 'hospital';

export const accountPages = {
  login: {
    title: 'Sign in to your workspace',
    description: 'Enter your email and password to access MediShield AI.',
    sidebarTitle: 'Connected healthcare starts here.',
    sidebarText: 'A workspace for care teams and patients.',
    submit: 'Sign in',
    unavailable: 'Sign-in is unavailable in this preview.',
  },
  recovery: {
    title: 'Forgot your password?',
    description: 'Enter the email address associated with your account.',
    sidebarTitle: 'Get back to your workspace.',
    sidebarText: 'Use your account email to request a password reset.',
    submit: 'Request password reset',
    unavailable: 'Password reset is unavailable in this preview. No email was sent.',
  },
  hospital: {
    title: 'Register Hospital',
    description: 'Enter your hospital details and the contact for your onboarding application.',
    sidebarTitle: 'Bring your hospital onboard.',
    sidebarText: 'The platform team reviews hospital applications before inviting the first hospital administrator.',
    submit: 'Submit application',
    unavailable: 'Hospital registration is unavailable in this preview. The application remains on this page.',
  },
} satisfies Record<AccountMode, { title: string; description: string; sidebarTitle: string; sidebarText: string; submit: string; unavailable: string }>;

type Field = { key: string; label: string; type?: 'email' | 'password' };

const email: Field = { key: 'email', label: 'Email address', type: 'email' };
const fields: Record<AccountMode, Field[]> = {
  login: [email, { key: 'password', label: 'Password', type: 'password' }],
  recovery: [email],
  hospital: [
    { key: 'legalName', label: 'Hospital legal name' },
    { key: 'businessReference', label: 'Registration number' },
    { key: 'city', label: 'City' },
    { key: 'timezone', label: 'Time zone (e.g. Asia/Kolkata)' },
    { ...email, label: 'Onboarding contact email' },
  ],
};

const linkStyle = 'self-start py-2 text-sm font-semibold text-emerald-800 dark:text-emerald-300 web:!text-primary';
const errorStyle = 'text-sm text-red-700 dark:text-red-300';

export function AccountForm({ mode }: { mode: AccountMode }) {
  const [values, setValues] = useState<Record<string, string>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [status, setStatus] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const page = accountPages[mode];

  function submit() {
    const nextErrors: Record<string, string> = {};
    for (const field of fields[mode]) {
      const value = values[field.key] ?? '';
      if (!(field.type === 'password' ? value : value.trim())) {
        nextErrors[field.key] = 'This field is required.';
      } else if (field.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())) {
        nextErrors[field.key] = 'Enter a valid email address.';
      }
    }

    setErrors(nextErrors);
    setStatus(Object.keys(nextErrors).length ? 'Check the highlighted fields.' : page.unavailable);
  }

  return (
    <View className="gap-4">
      <Text className="rounded-xl bg-[#eef6f1] px-4 py-3 text-sm leading-5 text-[#25483b] dark:bg-[#20352c] dark:text-emerald-100 web:!bg-accent web:!text-on-accent">
        Preview only. Use sample information.
      </Text>
      {fields[mode].map(({ key, label, type }, index) => (
        <View key={key} className="gap-1.5">
          <View className="min-h-6 flex-row items-center justify-between">
            <Text className="text-sm font-semibold text-[#13231d] dark:text-[#edf5f1] web:!text-ink">{label}</Text>
            {type === 'password' && (
              <Pressable accessibilityRole="button" accessibilityLabel={showPassword ? 'Hide password' : 'Show password'} hitSlop={8} onPress={() => setShowPassword((shown) => !shown)}>
                <Text className="text-sm font-semibold text-emerald-800 dark:text-emerald-300 web:!text-primary">{showPassword ? 'Hide' : 'Show'}</Text>
              </Pressable>
            )}
          </View>
          <TextInput
            accessibilityLabel={label}
            aria-invalid={Boolean(errors[key])}
            aria-describedby={errors[key] ? `${key}-error` : undefined}
            autoCapitalize={type ? 'none' : 'sentences'}
            autoComplete={type === 'password' ? 'current-password' : type === 'email' ? 'email' : 'off'}
            autoCorrect={!type}
            keyboardType={type === 'email' ? 'email-address' : 'default'}
            secureTextEntry={type === 'password' && !showPassword}
            value={values[key] ?? ''}
            onChangeText={(value) => {
              setValues((current) => ({ ...current, [key]: value }));
              setErrors((current) => ({ ...current, [key]: '' }));
              setStatus('');
            }}
            onSubmitEditing={index === fields[mode].length - 1 ? submit : undefined}
            className={`min-h-12 rounded-xl border bg-white px-3.5 text-base text-[#13231d] focus:border-emerald-600 dark:bg-[#182621] dark:text-[#edf5f1] web:!bg-surface web:!text-ink ${errors[key] ? 'border-red-600' : 'border-[#b6c8bf] dark:border-[#526d60] web:!border-control web:focus:!border-primary'}`}
          />
          {errors[key] ? <Text nativeID={`${key}-error`} className={errorStyle}>{errors[key]}</Text> : null}
        </View>
      ))}
      {mode === 'login' && <Link href="/forgot-password" className={linkStyle}>Forgot password?</Link>}
      <Pressable accessibilityRole="button" onPress={submit} className="min-h-12 items-center justify-center rounded-xl bg-emerald-800 px-4 py-3 active:bg-emerald-950 dark:bg-emerald-400 web:!bg-primary web:hover:!bg-primary-hover">
        <Text className="text-base font-bold text-white dark:text-emerald-950 web:!text-on-primary">{page.submit}</Text>
      </Pressable>
      {status ? <Text role="alert" accessibilityLiveRegion="polite" className="text-sm leading-5 text-[#42554c] dark:text-[#b9cbc2] web:!text-secondary">{status}</Text> : null}
      <View className="flex-row flex-wrap items-center gap-x-2 border-t border-[#dce5df] pt-2 dark:border-[#30443a] web:!border-border">
        {mode !== 'recovery' && <Text className="text-sm text-[#42554c] dark:text-[#b9cbc2] web:!text-secondary">{mode === 'login' ? 'New hospital?' : 'Already have an account?'}</Text>}
        {mode === 'login'
          ? <Link href="/register-hospital" className={linkStyle}>Register Hospital</Link>
          : <Link href="/login" className={linkStyle}>{mode === 'recovery' ? 'Back to sign in' : 'Sign in'}</Link>}
      </View>
    </View>
  );
}
