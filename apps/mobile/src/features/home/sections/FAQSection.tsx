import { questions } from '../content';
import { SectionHeading } from './section-content';
import { container } from '../styles';
import { sectionSpacing, sectionSplit } from './section-layout';

export function FAQSection() {
  return (
    <section id="faq" className={sectionSpacing} aria-labelledby="faq-title">
      <div className={`${container} ${sectionSplit}`}>
        <SectionHeading id="faq-title" label="FAQ" title="Frequently Asked Questions" />
        <div className="min-w-0 border-t border-border">
          {questions.map((item) => (
            <details className="group border-b border-border" key={item.title} name="home-faq">
              <summary className="relative min-h-14 cursor-pointer list-none rounded-md py-4 pl-1 pr-11 text-base font-[620] leading-[1.45] text-ink hover:text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus [&::-webkit-details-marker]:hidden">
                {item.title}
                <span
                  aria-hidden="true"
                  className="absolute right-3 top-7 h-0.5 w-3 rounded bg-primary after:block after:h-full after:w-full after:rotate-90 after:rounded after:bg-primary after:content-[''] group-open:after:hidden"
                />
              </summary>
              <p className="mb-4 ml-1 mr-11 max-w-[42rem] text-base leading-[1.65] text-secondary">
                {item.description}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
